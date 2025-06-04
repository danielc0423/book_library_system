"""
Celery tasks for the analytics app.
"""
from celery import shared_task
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.db import models
from analytics.models import UserCreditScore, SystemAnalytics
from books.models import BorrowingRecord
import logging

logger = logging.getLogger(__name__)
User = get_user_model()


@shared_task
def update_user_credit_score(user_id, borrowing_record_id=None):
    """
    Update credit score for a specific user.
    
    Args:
        user_id: ID of the user
        borrowing_record_id: Optional ID of the borrowing record that triggered update
    """
    try:
        credit_score = UserCreditScore.objects.get(user_id=user_id)
        credit_score.calculate_score()
        
        logger.info(f"Updated credit score for user {user_id}: {credit_score.credit_score}")
        return f"Updated credit score: {credit_score.credit_score}"
    except UserCreditScore.DoesNotExist:
        logger.error(f"Credit score not found for user {user_id}")
        return f"Credit score not found for user {user_id}"
    except Exception as e:
        logger.error(f"Error updating credit score: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def update_all_credit_scores():
    """
    Update credit scores for all users (daily task).
    """
    try:
        count = 0
        for credit_score in UserCreditScore.objects.all():
            credit_score.calculate_score()
            count += 1
        
        logger.info(f"Updated {count} credit scores")
        return f"Updated {count} credit scores"
    except Exception as e:
        logger.error(f"Error updating all credit scores: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def calculate_book_popularity():
    """
    Calculate book popularity scores based on borrowing patterns.
    """
    try:
        from books.models import BookStatistics
        
        # Update all book statistics
        count = 0
        for stats in BookStatistics.objects.all():
            stats.update_statistics()
            count += 1
        
        # Identify trending books (borrowed frequently in last 30 days)
        recent_date = timezone.now() - timezone.timedelta(days=30)
        trending_books = BorrowingRecord.objects.filter(
            borrow_date__gte=recent_date
        ).values('book__title', 'book__author').annotate(
            borrow_count=models.Count('id')
        ).order_by('-borrow_count')[:10]
        
        logger.info(f"Updated popularity for {count} books")
        return {
            'updated_count': count,
            'trending_books': list(trending_books)
        }
    except Exception as e:
        logger.error(f"Error calculating book popularity: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def sync_credit_score_cross_systems(user_id):
    """
    Sync credit score across integrated systems.
    
    Args:
        user_id: ID of the user
    """
    try:
        credit_score = UserCreditScore.objects.get(user_id=user_id)
        
        # This would integrate with other systems via OIC
        # For now, we'll simulate cross-system sync
        
        # Example: Sync with bike rental system
        if credit_score.credit_score >= 700:
            credit_score.system_privileges['bike_rental']['premium_member'] = True
        
        # Example: Sync with equipment rental
        if credit_score.credit_score >= 600:
            credit_score.system_privileges['equipment_rental']['verified'] = True
        
        credit_score.last_cross_sync = timezone.now()
        credit_score.save()
        
        logger.info(f"Synced credit score across systems for user {user_id}")
        return f"Cross-system sync completed for user {user_id}"
    except UserCreditScore.DoesNotExist:
        logger.error(f"Credit score not found for user {user_id}")
        return f"Credit score not found for user {user_id}"
    except Exception as e:
        logger.error(f"Error syncing credit score: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def generate_daily_analytics():
    """
    Generate daily system analytics.
    """
    try:
        yesterday = timezone.now().date() - timezone.timedelta(days=1)
        analytics = SystemAnalytics.generate_daily_analytics(yesterday)
        
        logger.info(f"Generated analytics for {yesterday}")
        return f"Analytics generated for {yesterday}"
    except Exception as e:
        logger.error(f"Error generating daily analytics: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def identify_at_risk_users():
    """
    Identify users at risk of credit score decline.
    """
    try:
        from notifications.models import NotificationQueue
        
        at_risk_users = []
        
        # Find users with declining scores
        for credit_score in UserCreditScore.objects.filter(
            credit_score__lt=700,
            credit_score__gt=500
        ):
            # Check if user has overdue books
            overdue_count = BorrowingRecord.objects.filter(
                user=credit_score.user,
                status='overdue'
            ).count()
            
            if overdue_count > 0:
                at_risk_users.append(credit_score.user)
                
                # Send warning notification
                NotificationQueue.objects.create(
                    user=credit_score.user,
                    notification_type='credit_warning',
                    scheduled_for=timezone.now(),
                    priority='normal',
                    data={
                        'current_score': float(credit_score.credit_score),
                        'overdue_books': overdue_count,
                        'risk_level': 'medium' if credit_score.credit_score > 600 else 'high'
                    }
                )
        
        logger.info(f"Identified {len(at_risk_users)} at-risk users")
        return f"Identified {len(at_risk_users)} at-risk users"
    except Exception as e:
        logger.error(f"Error identifying at-risk users: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def generate_user_insights(user_id):
    """
    Generate personalized insights for a user.
    
    Args:
        user_id: ID of the user
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Gather user statistics
        total_borrowed = BorrowingRecord.objects.filter(user=user).count()
        on_time_returns = BorrowingRecord.objects.filter(
            user=user,
            status='returned',
            return_date__lte=models.F('due_date')
        ).count()
        
        favorite_categories = BorrowingRecord.objects.filter(
            user=user
        ).values('book__category__name').annotate(
            count=models.Count('id')
        ).order_by('-count')[:3]
        
        insights = {
            'total_books_borrowed': total_borrowed,
            'on_time_return_rate': (on_time_returns / total_borrowed * 100) if total_borrowed > 0 else 0,
            'favorite_categories': list(favorite_categories),
            'credit_score': float(user.credit_score.credit_score) if hasattr(user, 'credit_score') else 750,
            'member_since': user.registration_date.date().isoformat() if hasattr(user, 'registration_date') else user.date_joined.date().isoformat()
        }
        
        logger.info(f"Generated insights for user {user_id}")
        return insights
    except User.DoesNotExist:
        logger.error(f"User {user_id} not found")
        return f"User {user_id} not found"
    except Exception as e:
        logger.error(f"Error generating user insights: {str(e)}")
        return f"Error: {str(e)}"
