"""
Celery tasks for the books app.
"""
from celery import shared_task
from django.utils import timezone
from books.models import Book, BorrowingRecord, BookStatistics
import logging

logger = logging.getLogger(__name__)


@shared_task
def update_overdue_status():
    """
    Update status of borrowing records that have become overdue.
    """
    try:
        overdue_records = BorrowingRecord.objects.filter(
            status='borrowed',
            due_date__lt=timezone.now()
        )
        
        count = overdue_records.update(status='overdue')
        logger.info(f"Updated {count} records to overdue status")
        
        # Trigger overdue notifications
        from notifications.tasks import send_overdue_notifications
        send_overdue_notifications.delay()
        
        return f"Updated {count} overdue records"
    except Exception as e:
        logger.error(f"Error updating overdue status: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def calculate_all_book_statistics():
    """
    Calculate statistics for all books.
    """
    try:
        count = 0
        for book in Book.objects.filter(is_active=True):
            stats, created = BookStatistics.objects.get_or_create(book=book)
            stats.update_statistics()
            count += 1
        
        logger.info(f"Updated statistics for {count} books")
        return f"Updated statistics for {count} books"
    except Exception as e:
        logger.error(f"Error calculating book statistics: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def cleanup_lost_books():
    """
    Mark books as lost if they've been overdue for more than 90 days.
    """
    try:
        cutoff_date = timezone.now() - timezone.timedelta(days=90)
        lost_records = BorrowingRecord.objects.filter(
            status='overdue',
            due_date__lt=cutoff_date
        )
        
        count = 0
        for record in lost_records:
            record.status = 'lost'
            record.save()
            
            # Update book availability
            book = record.book
            if book.available_copies > 0:
                book.available_copies -= 1
                book.save()
            
            count += 1
        
        logger.info(f"Marked {count} books as lost")
        return f"Marked {count} books as lost"
    except Exception as e:
        logger.error(f"Error marking books as lost: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def generate_inventory_report():
    """
    Generate inventory report for all books.
    """
    try:
        from django.db.models import Sum, Count
        
        total_books = Book.objects.filter(is_active=True).count()
        total_copies = Book.objects.filter(is_active=True).aggregate(
            Sum('total_copies')
        )['total_copies__sum'] or 0
        
        available_copies = Book.objects.filter(is_active=True).aggregate(
            Sum('available_copies')
        )['available_copies__sum'] or 0
        
        borrowed_copies = total_copies - available_copies
        
        out_of_stock = Book.objects.filter(
            is_active=True,
            available_copies=0
        ).count()
        
        report = {
            'total_unique_books': total_books,
            'total_copies': total_copies,
            'available_copies': available_copies,
            'borrowed_copies': borrowed_copies,
            'out_of_stock_books': out_of_stock,
            'utilization_rate': (borrowed_copies / total_copies * 100) if total_copies > 0 else 0,
            'generated_at': timezone.now().isoformat()
        }
        
        logger.info(f"Generated inventory report: {report}")
        return report
    except Exception as e:
        logger.error(f"Error generating inventory report: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def check_low_inventory():
    """
    Check for books with low inventory and notify administrators.
    """
    try:
        from notifications.models import NotificationQueue
        from django.contrib.auth import get_user_model
        
        User = get_user_model()
        
        # Find books with less than 20% available
        low_stock_books = []
        for book in Book.objects.filter(is_active=True, total_copies__gt=0):
            availability_rate = book.available_copies / book.total_copies
            if availability_rate < 0.2:  # Less than 20% available
                low_stock_books.append({
                    'title': book.title,
                    'author': book.author,
                    'available': book.available_copies,
                    'total': book.total_copies
                })
        
        if low_stock_books:
            # Notify all admin users
            admins = User.objects.filter(is_staff=True, is_active=True)
            for admin in admins:
                NotificationQueue.objects.create(
                    user=admin,
                    notification_type='low_inventory',
                    scheduled_for=timezone.now(),
                    priority='high',
                    data={
                        'books': low_stock_books,
                        'count': len(low_stock_books)
                    }
                )
        
        logger.info(f"Found {len(low_stock_books)} books with low inventory")
        return f"Found {len(low_stock_books)} books with low inventory"
    except Exception as e:
        logger.error(f"Error checking inventory: {str(e)}")
        return f"Error: {str(e)}"
