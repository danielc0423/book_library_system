"""
Celery tasks for the notifications app.
"""
from celery import shared_task
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.conf import settings
from notifications.models import (
    NotificationTemplate, NotificationLog, NotificationQueue,
    NotificationPreference
)
from books.models import BorrowingRecord
import logging

logger = logging.getLogger(__name__)
User = get_user_model()


@shared_task
def send_overdue_reminders():
    """
    Send reminders for overdue books (daily task).
    """
    try:
        overdue_records = BorrowingRecord.objects.filter(
            status='overdue',
            reminder_sent=False
        )
        
        count = 0
        for record in overdue_records:
            # Check user preferences
            preferences = NotificationPreference.objects.get(user=record.user)
            if preferences.can_send_notification('overdue_notice'):
                NotificationQueue.objects.create(
                    user=record.user,
                    notification_type='overdue_notice',
                    scheduled_for=timezone.now(),
                    priority='high',
                    data={
                        'book_title': record.book.title,
                        'due_date': record.due_date.strftime('%Y-%m-%d'),
                        'days_overdue': record.days_overdue,
                        'late_fee': float(record.calculate_late_fee())
                    }
                )
                record.reminder_sent = True
                record.save()
                count += 1
        
        logger.info(f"Queued {count} overdue reminders")
        return f"Queued {count} overdue reminders"
    except Exception as e:
        logger.error(f"Error sending overdue reminders: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def send_pre_due_reminders():
    """
    Send reminders before due date (daily task).
    """
    try:
        reminder_days = getattr(settings, 'REMINDER_DAYS_BEFORE_DUE', 3)
        reminder_date = timezone.now().date() + timezone.timedelta(days=reminder_days)
        
        upcoming_due = BorrowingRecord.objects.filter(
            status='borrowed',
            due_date__date=reminder_date,
            reminder_sent=False
        )
        
        count = 0
        for record in upcoming_due:
            preferences = NotificationPreference.objects.get(user=record.user)
            if preferences.can_send_notification('pre_due_reminder'):
                NotificationQueue.objects.create(
                    user=record.user,
                    notification_type='pre_due_reminder',
                    scheduled_for=timezone.now(),
                    priority='normal',
                    data={
                        'book_title': record.book.title,
                        'due_date': record.due_date.strftime('%Y-%m-%d'),
                        'days_until_due': reminder_days
                    }
                )
                count += 1
        
        logger.info(f"Queued {count} pre-due reminders")
        return f"Queued {count} pre-due reminders"
    except Exception as e:
        logger.error(f"Error sending pre-due reminders: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def process_notification_queue():
    """
    Process pending notifications in the queue.
    """
    try:
        # Get notifications that should be sent now
        pending_notifications = NotificationQueue.objects.filter(
            is_processed=False,
            scheduled_for__lte=timezone.now()
        ).order_by('scheduled_for', '-priority')[:100]  # Process 100 at a time
        
        count = 0
        for notification in pending_notifications:
            if notification.process():
                count += 1
        
        logger.info(f"Processed {count} notifications")
        return f"Processed {count} notifications"
    except Exception as e:
        logger.error(f"Error processing notification queue: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def send_notification(user_id, notification_type, data):
    """
    Send a specific notification to a user.
    
    Args:
        user_id: ID of the user
        notification_type: Type of notification
        data: Data for the notification template
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Get template
        template = NotificationTemplate.objects.get(
            template_type=notification_type,
            is_active=True
        )
        
        # Check preferences
        preferences = NotificationPreference.objects.get(user=user)
        if not preferences.can_send_notification(notification_type):
            logger.info(f"User {user_id} has disabled {notification_type} notifications")
            return f"Notification disabled by user preferences"
        
        # Create notification log
        notification_log = NotificationLog.objects.create(
            user=user,
            template=template,
            notification_type=notification_type,
            subject=template.subject.format(**data),
            recipient_email=user.email,
            status='pending',
            metadata={
                'html_content': template.html_template.format(**data),
                'text_content': template.text_template.format(**data),
                'data': data
            }
        )
        
        # Send the notification
        notification_log.send()
        
        logger.info(f"Sent {notification_type} notification to user {user_id}")
        return f"Notification sent successfully"
    except User.DoesNotExist:
        logger.error(f"User {user_id} not found")
        return f"User not found"
    except NotificationTemplate.DoesNotExist:
        logger.error(f"Template for {notification_type} not found")
        return f"Template not found"
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def send_bulk_notification(user_ids, notification_type, data):
    """
    Send notification to multiple users.
    
    Args:
        user_ids: List of user IDs
        notification_type: Type of notification
        data: Data for the notification template
    """
    try:
        count = 0
        for user_id in user_ids:
            result = send_notification.delay(user_id, notification_type, data)
            if result:
                count += 1
        
        logger.info(f"Queued {count} bulk notifications")
        return f"Queued {count} notifications"
    except Exception as e:
        logger.error(f"Error sending bulk notifications: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def cleanup_old_notifications():
    """
    Clean up old notification logs (monthly task).
    """
    try:
        # Delete logs older than 90 days
        cutoff_date = timezone.now() - timezone.timedelta(days=90)
        old_logs = NotificationLog.objects.filter(
            created_at__lt=cutoff_date
        )
        count = old_logs.count()
        old_logs.delete()
        
        # Also clean up processed queue items older than 30 days
        old_queue = NotificationQueue.objects.filter(
            is_processed=True,
            processed_at__lt=timezone.now() - timezone.timedelta(days=30)
        )
        queue_count = old_queue.count()
        old_queue.delete()
        
        logger.info(f"Cleaned up {count} old logs and {queue_count} queue items")
        return f"Cleaned up {count} logs and {queue_count} queue items"
    except Exception as e:
        logger.error(f"Error cleaning up notifications: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def send_overdue_notifications():
    """
    Send notifications for newly overdue books.
    """
    try:
        # Find books that just became overdue today
        today_overdue = BorrowingRecord.objects.filter(
            status='overdue',
            due_date__date=timezone.now().date() - timezone.timedelta(days=1),
            reminder_sent=False
        )
        
        count = 0
        for record in today_overdue:
            preferences = NotificationPreference.objects.get(user=record.user)
            if preferences.can_send_notification('overdue_notice'):
                NotificationQueue.objects.create(
                    user=record.user,
                    notification_type='overdue_notice',
                    scheduled_for=timezone.now(),
                    priority='urgent',
                    data={
                        'book_title': record.book.title,
                        'due_date': record.due_date.strftime('%Y-%m-%d'),
                        'days_overdue': 1,
                        'late_fee': float(settings.LATE_FEE_PER_DAY)
                    }
                )
                count += 1
        
        logger.info(f"Queued {count} new overdue notifications")
        return f"Queued {count} overdue notifications"
    except Exception as e:
        logger.error(f"Error sending overdue notifications: {str(e)}")
        return f"Error: {str(e)}"
