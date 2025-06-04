"""
Signal handlers for the notifications app.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from notifications.models import NotificationLog
from analytics.models import UserActivityLog


@receiver(post_save, sender=NotificationLog)
def log_notification_activity(sender, instance, created, **kwargs):
    """
    Log notification sending as user activity.
    """
    if instance.status == 'sent' and not created:
        # Notification was just sent successfully
        UserActivityLog.objects.create(
            user=instance.user,
            action='notification',
            details={
                'type': instance.notification_type,
                'subject': instance.subject,
                'sent_at': instance.sent_at.isoformat() if instance.sent_at else None
            }
        )
