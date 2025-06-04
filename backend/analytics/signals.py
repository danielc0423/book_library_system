"""
Signal handlers for the analytics app.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from analytics.models import UserCreditScore
from notifications.models import NotificationQueue
from django.utils import timezone


@receiver(post_save, sender=UserCreditScore)
def notify_credit_score_changes(sender, instance, created, **kwargs):
    """
    Send notification when credit score changes significantly.
    """
    if created:
        return  # Don't notify on initial creation
    
    # Check if score changed significantly (50+ points)
    try:
        old_score = UserCreditScore.objects.get(pk=instance.pk).credit_score
        score_change = abs(float(instance.credit_score) - float(old_score))
        
        if score_change >= 50:
            # Schedule credit score update notification
            NotificationQueue.objects.create(
                user=instance.user,
                notification_type='credit_score_update',
                scheduled_for=timezone.now(),
                priority='normal',
                data={
                    'old_score': float(old_score),
                    'new_score': float(instance.credit_score),
                    'rating': instance.reliability_rating,
                    'max_books': instance.max_books_allowed,
                    'direction': 'increased' if instance.credit_score > old_score else 'decreased'
                }
            )
            
            # If score dropped below 500, notify about account restrictions
            if float(instance.credit_score) < 500 and float(old_score) >= 500:
                NotificationQueue.objects.create(
                    user=instance.user,
                    notification_type='account_suspended',
                    scheduled_for=timezone.now(),
                    priority='urgent',
                    data={
                        'reason': 'low_credit_score',
                        'score': float(instance.credit_score),
                        'max_books': instance.max_books_allowed
                    }
                )
    except UserCreditScore.DoesNotExist:
        pass


@receiver(post_save, sender=UserCreditScore)
def sync_cross_system_privileges(sender, instance, created, **kwargs):
    """
    Sync privileges across integrated systems when credit score changes.
    """
    if not created:
        # Trigger cross-system sync
        from analytics.tasks import sync_credit_score_cross_systems
        sync_credit_score_cross_systems.delay(instance.user.id)
