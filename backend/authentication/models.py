"""
Custom user model for the library system with Oracle IDCS integration.
"""
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.core.validators import RegexValidator
from django.utils import timezone


class CustomUser(AbstractUser):
    """
    Extended User model with library-specific fields and Oracle IDCS integration.
    """
    
    USER_TYPE_CHOICES = [
        ('student', 'Student'),
        ('faculty', 'Faculty'),
        ('staff', 'Staff'),
        ('admin', 'Administrator'),
    ]
    
    # Additional user fields
    phone_number = models.CharField(
        max_length=20,
        blank=True,
        validators=[
            RegexValidator(
                regex=r'^\+?1?\d{9,15}$',
                message="Phone number must be entered in the format: '+999999999'. Up to 15 digits allowed."
            )
        ],
        help_text="Contact phone number"
    )
    
    user_type = models.CharField(
        max_length=20,
        choices=USER_TYPE_CHOICES,
        default='student',
        help_text="Type of library user"
    )
    
    max_books_allowed = models.PositiveIntegerField(
        default=5,
        help_text="Maximum number of books this user can borrow"
    )
    
    registration_date = models.DateTimeField(
        default=timezone.now,
        help_text="Date when the user registered"
    )
    
    last_login_date = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Last successful login timestamp"
    )
    
    # Verification fields
    email_verified = models.BooleanField(
        default=False,
        help_text="Whether the email address has been verified"
    )
    
    phone_verified = models.BooleanField(
        default=False,
        help_text="Whether the phone number has been verified"
    )
    
    # Oracle IDCS Integration Fields
    idcs_user_id = models.CharField(
        max_length=100,
        unique=True,
        null=True,
        blank=True,
        help_text="Unique identifier from Oracle IDCS"
    )
    
    idcs_guid = models.CharField(
        max_length=100,
        unique=True,
        null=True,
        blank=True,
        help_text="Oracle IDCS GUID"
    )
    
    idcs_last_sync = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Last synchronization with Oracle IDCS"
    )
    
    idcs_groups = models.JSONField(
        default=list,
        blank=True,
        help_text="IDCS group memberships"
    )
    
    # Multi-factor authentication
    mfa_enabled = models.BooleanField(
        default=False,
        help_text="Whether MFA is enabled for this user"
    )
    
    # Backup contact
    backup_email = models.EmailField(
        blank=True,
        help_text="Secondary email for account recovery"
    )
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'library_users'
        verbose_name = 'Library User'
        verbose_name_plural = 'Library Users'
        indexes = [
            models.Index(fields=['email']),
            models.Index(fields=['idcs_user_id']),
            models.Index(fields=['user_type']),
        ]
    
    def __str__(self):
        return f"{self.get_full_name() or self.username} ({self.user_type})"
    
    def get_borrowing_limit(self):
        """
        Get the borrowing limit for this user based on type and credit score.
        """
        from library_system.utils import get_user_borrowing_limit
        return get_user_borrowing_limit(self)
    
    def can_borrow_more_books(self):
        """
        Check if the user can borrow more books.
        """
        from books.models import BorrowingRecord
        current_borrowed = BorrowingRecord.objects.filter(
            user=self,
            status='borrowed'
        ).count()
        return current_borrowed < self.get_borrowing_limit()
    
    def sync_with_idcs(self):
        """
        Synchronize user data with Oracle IDCS.
        """
        # This will be implemented with actual IDCS API calls
        self.idcs_last_sync = timezone.now()
        self.save(update_fields=['idcs_last_sync'])
    
    @property
    def is_idcs_user(self):
        """Check if this user is synchronized with IDCS."""
        return bool(self.idcs_user_id)
    
    @property
    def full_name(self):
        """Get user's full name."""
        return self.get_full_name() or self.username
