"""
Signal handlers for the authentication app.
"""
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model
from notifications.models import NotificationPreference, NotificationQueue
from analytics.models import UserCreditScore
from django.utils import timezone

User = get_user_model()


@receiver(post_save, sender=User)
def create_user_related_models(sender, instance, created, **kwargs):
    """
    Create related models when a new user is created.
    """
    if created:
        # Create notification preferences
        NotificationPreference.objects.get_or_create(user=instance)
        
        # Create credit score record
        UserCreditScore.objects.get_or_create(
            user=instance,
            defaults={
                'credit_score': 750,
                'reliability_rating': 'Good',
                'max_books_allowed': 5
            }
        )
        
        # Schedule welcome email
        NotificationQueue.objects.create(
            user=instance,
            notification_type='welcome',
            scheduled_for=timezone.now(),
            priority='high',
            data={
                'user_name': instance.get_full_name() or instance.username,
                'email': instance.email
            }
        )


@receiver(pre_save, sender=User)
def update_last_login_date(sender, instance, **kwargs):
    """
    Update last_login_date when user logs in.
    """
    if instance.pk and instance.last_login:
        try:
            old_instance = User.objects.get(pk=instance.pk)
            if old_instance.last_login != instance.last_login:
                instance.last_login_date = timezone.now()
        except User.DoesNotExist:
            pass


@receiver(post_save, sender=User)
def sync_with_idcs(sender, instance, created, **kwargs):
    """
    Sync user with Oracle IDCS if enabled.
    """
    from django.conf import settings
    
    if settings.IDCS_ENABLED and not created:
        # Only sync existing users, not new ones
        from authentication.tasks import sync_user_with_idcs
        sync_user_with_idcs.delay(instance.id)
