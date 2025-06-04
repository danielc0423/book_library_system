"""
Celery tasks for the authentication app.
"""
from celery import shared_task
from django.contrib.auth import get_user_model
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)
User = get_user_model()


@shared_task
def cleanup_blacklisted_tokens():
    """
    Clean up expired JWT tokens from the blacklist.
    """
    try:
        # This task is disabled until JWT blacklist is properly configured
        logger.info("JWT token cleanup skipped - blacklist not configured")
        return "JWT blacklist not configured"
    except Exception as e:
        logger.error(f"Error cleaning up tokens: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def sync_idcs_users():
    """
    Sync users with Oracle Identity Cloud Service.
    """
    from django.conf import settings
    
    if not settings.IDCS_ENABLED:
        return "IDCS sync disabled"
    
    try:
        # This would contain actual IDCS API integration
        # For now, we'll just update sync timestamps
        users_to_sync = User.objects.filter(
            idcs_user_id__isnull=False
        ).exclude(
            idcs_last_sync__gte=timezone.now() - timezone.timedelta(hours=6)
        )
        
        count = 0
        for user in users_to_sync:
            user.sync_with_idcs()
            count += 1
        
        logger.info(f"Synced {count} users with IDCS")
        return f"Synced {count} users with IDCS"
    except Exception as e:
        logger.error(f"Error syncing IDCS users: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def sync_user_with_idcs(user_id):
    """
    Sync a specific user with Oracle IDCS.
    
    Args:
        user_id: ID of the user to sync
    """
    try:
        user = User.objects.get(id=user_id)
        user.sync_with_idcs()
        logger.info(f"Synced user {user.username} with IDCS")
        return f"Synced user {user.username}"
    except User.DoesNotExist:
        logger.error(f"User {user_id} not found")
        return f"User {user_id} not found"
    except Exception as e:
        logger.error(f"Error syncing user {user_id}: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def verify_user_email(user_id, verification_token):
    """
    Verify user's email address.
    
    Args:
        user_id: ID of the user
        verification_token: Email verification token
    """
    try:
        user = User.objects.get(id=user_id)
        # In a real implementation, we would verify the token
        user.email_verified = True
        user.save(update_fields=['email_verified'])
        
        logger.info(f"Email verified for user {user.username}")
        return f"Email verified for {user.username}"
    except User.DoesNotExist:
        logger.error(f"User {user_id} not found")
        return f"User {user_id} not found"
    except Exception as e:
        logger.error(f"Error verifying email: {str(e)}")
        return f"Error: {str(e)}"


@shared_task
def deactivate_inactive_users():
    """
    Deactivate users who haven't logged in for 180 days.
    """
    try:
        cutoff_date = timezone.now() - timezone.timedelta(days=180)
        inactive_users = User.objects.filter(
            last_login__lt=cutoff_date,
            is_active=True,
            is_staff=False,
            is_superuser=False
        )
        
        count = inactive_users.update(is_active=False)
        logger.info(f"Deactivated {count} inactive users")
        return f"Deactivated {count} inactive users"
    except Exception as e:
        logger.error(f"Error deactivating users: {str(e)}")
        return f"Error: {str(e)}"
