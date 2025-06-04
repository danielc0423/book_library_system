"""
Signal handlers for the books app.
"""
from django.db.models.signals import post_save, pre_save, post_delete
from django.dispatch import receiver
from django.utils import timezone
from books.models import Book, BorrowingRecord, BookStatistics
from analytics.models import UserCreditScore, UserActivityLog
from notifications.models import NotificationQueue
from django.conf import settings


@receiver(post_save, sender=Book)
def create_book_statistics(sender, instance, created, **kwargs):
    """
    Create BookStatistics record when a new book is created.
    """
    if created:
        BookStatistics.objects.get_or_create(book=instance)


@receiver(post_save, sender=BorrowingRecord)
def update_book_availability(sender, instance, created, **kwargs):
    """
    Update book availability and statistics when borrowing changes.
    """
    if created:
        # New borrowing - decrease available copies
        instance.book.borrow()
        
        # Update book statistics
        if hasattr(instance.book, 'statistics'):
            stats = instance.book.statistics
            stats.total_borrowed_count += 1
            stats.current_borrowed_count += 1
            stats.last_borrowed_date = instance.borrow_date
            stats.save()
        
        # Log activity
        UserActivityLog.objects.create(
            user=instance.user,
            action='borrow',
            details={
                'book_id': str(instance.book.book_id),
                'book_title': instance.book.title,
                'due_date': instance.due_date.isoformat()
            }
        )
        
        # Send borrowing confirmation
        NotificationQueue.objects.create(
            user=instance.user,
            notification_type='borrow_confirmation',
            scheduled_for=timezone.now(),
            priority='high',
            data={
                'book_title': instance.book.title,
                'due_date': instance.due_date.strftime('%Y-%m-%d'),
                'borrow_date': instance.borrow_date.strftime('%Y-%m-%d')
            }
        )
        
        # Schedule pre-due reminder
        reminder_days = getattr(settings, 'REMINDER_DAYS_BEFORE_DUE', 3)
        reminder_date = instance.due_date - timezone.timedelta(days=reminder_days)
        
        NotificationQueue.objects.create(
            user=instance.user,
            notification_type='pre_due_reminder',
            scheduled_for=reminder_date,
            priority='normal',
            data={
                'book_title': instance.book.title,
                'due_date': instance.due_date.strftime('%Y-%m-%d'),
                'days_until_due': reminder_days
            }
        )


@receiver(pre_save, sender=BorrowingRecord)
def check_overdue_status(sender, instance, **kwargs):
    """
    Check and update overdue status before saving.
    """
    if instance.pk:  # Existing record
        if instance.status == 'borrowed' and instance.is_overdue:
            instance.status = 'overdue'
            
            # Schedule overdue notification if not already sent
            if not instance.reminder_sent:
                NotificationQueue.objects.create(
                    user=instance.user,
                    notification_type='overdue_notice',
                    scheduled_for=timezone.now(),
                    priority='high',
                    data={
                        'book_title': instance.book.title,
                        'due_date': instance.due_date.strftime('%Y-%m-%d'),
                        'days_overdue': instance.days_overdue,
                        'late_fee': float(instance.calculate_late_fee())
                    }
                )
                instance.reminder_sent = True


@receiver(post_save, sender=BorrowingRecord)
def update_credit_score_on_return(sender, instance, created, **kwargs):
    """
    Update user's credit score when a book is returned.
    """
    if not created and instance.status == 'returned' and instance.return_date:
        # Book was just returned
        credit_score = instance.user.credit_score
        
        # Update metrics
        credit_score.total_books_borrowed += 1
        
        if instance.days_overdue > 0:
            credit_score.late_returns += 1
            # Update average delay
            total_delay = (credit_score.average_return_delay * 
                          (credit_score.late_returns - 1) + instance.days_overdue)
            credit_score.average_return_delay = total_delay / credit_score.late_returns
        else:
            credit_score.on_time_returns += 1
        
        # Recalculate score
        credit_score.calculate_score()
        
        # Update book statistics
        if hasattr(instance.book, 'statistics'):
            stats = instance.book.statistics
            stats.current_borrowed_count = max(0, stats.current_borrowed_count - 1)
            stats.update_statistics()
        
        # Log return activity
        UserActivityLog.objects.create(
            user=instance.user,
            action='return',
            details={
                'book_id': str(instance.book.book_id),
                'book_title': instance.book.title,
                'return_date': instance.return_date.isoformat(),
                'was_overdue': instance.days_overdue > 0,
                'late_fee': float(instance.late_fees)
            }
        )
        
        # Send return confirmation
        NotificationQueue.objects.create(
            user=instance.user,
            notification_type='return_confirmation',
            scheduled_for=timezone.now(),
            priority='normal',
            data={
                'book_title': instance.book.title,
                'return_date': instance.return_date.strftime('%Y-%m-%d'),
                'late_fee': float(instance.late_fees) if instance.late_fees > 0 else None
            }
        )


@receiver(post_save, sender=BorrowingRecord)
def handle_renewal(sender, instance, created, **kwargs):
    """
    Handle book renewal notifications.
    """
    if not created and instance.status == 'renewed':
        # Book was renewed
        UserActivityLog.objects.create(
            user=instance.user,
            action='renew',
            details={
                'book_id': str(instance.book.book_id),
                'book_title': instance.book.title,
                'new_due_date': instance.due_date.isoformat(),
                'renewal_count': instance.renewal_count
            }
        )
        
        # Send renewal confirmation
        NotificationQueue.objects.create(
            user=instance.user,
            notification_type='renewal_confirmation',
            scheduled_for=timezone.now(),
            priority='normal',
            data={
                'book_title': instance.book.title,
                'new_due_date': instance.due_date.strftime('%Y-%m-%d'),
                'renewals_remaining': instance.max_renewals - instance.renewal_count
            }
        )


@receiver(post_delete, sender=Book)
def cleanup_book_statistics(sender, instance, **kwargs):
    """
    Clean up related statistics when a book is deleted.
    """
    # Statistics will be automatically deleted due to OneToOneField CASCADE
    pass
