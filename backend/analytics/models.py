"""
Analytics models for tracking user behavior and credit scores.
"""
from django.db import models
from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from decimal import Decimal


class UserCreditScore(models.Model):
    """
    Credit scoring system for users with cross-system integration capabilities.
    """
    RATING_CHOICES = [
        ('Excellent', 'Excellent (900-1000)'),
        ('Very Good', 'Very Good (800-899)'),
        ('Good', 'Good (700-799)'),
        ('Fair', 'Fair (600-699)'),
        ('Poor', 'Poor (500-599)'),
        ('Very Poor', 'Very Poor (Below 500)'),
    ]
    
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='credit_score'
    )
    
    # Core credit score
    credit_score = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=750.00,
        validators=[MinValueValidator(0), MaxValueValidator(1000)],
        help_text="Credit score on a 0-1000 scale"
    )
    
    # Library-specific metrics
    on_time_returns = models.PositiveIntegerField(
        default=0,
        help_text="Number of books returned on time"
    )
    
    late_returns = models.PositiveIntegerField(
        default=0,
        help_text="Number of books returned late"
    )
    
    total_books_borrowed = models.PositiveIntegerField(
        default=0,
        help_text="Total number of books borrowed"
    )
    
    average_return_delay = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0.00,
        help_text="Average delay in days for late returns"
    )
    
    reliability_rating = models.CharField(
        max_length=20,
        choices=RATING_CHOICES,
        default='Good',
        help_text="Overall reliability rating"
    )
    
    max_books_allowed = models.PositiveIntegerField(
        default=5,
        help_text="Maximum books allowed based on credit score"
    )
    
    # Cross-system integration fields
    external_system_scores = models.JSONField(
        default=dict,
        blank=True,
        help_text="Credit scores from other integrated systems"
    )
    
    composite_score = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=750.00,
        validators=[MinValueValidator(0), MaxValueValidator(1000)],
        help_text="Weighted score across all integrated systems"
    )
    
    system_privileges = models.JSONField(
        default=dict,
        blank=True,
        help_text="Cross-system privileges based on composite score"
    )
    
    last_cross_sync = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Last synchronization across systems"
    )
    
    # Metadata
    last_calculated = models.DateTimeField(
        auto_now=True,
        help_text="Last time the credit score was calculated"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'user_credit_scores'
        verbose_name = 'User Credit Score'
        verbose_name_plural = 'User Credit Scores'
        ordering = ['-credit_score']
    
    def __str__(self):
        return f"{self.user.username} - Score: {self.credit_score} ({self.reliability_rating})"
    
    def calculate_score(self):
        """
        Calculate credit score based on borrowing behavior.
        """
        if self.total_books_borrowed == 0:
            # New user with no history
            self.credit_score = 750
            self.reliability_rating = 'Good'
        else:
            # Calculate on-time return rate
            on_time_rate = self.on_time_returns / self.total_books_borrowed
            
            # Base score calculation
            base_score = 500  # Starting point
            
            # Add points for on-time returns (max 300 points)
            base_score += on_time_rate * 300
            
            # Add points for borrowing history (max 100 points)
            history_points = min(100, self.total_books_borrowed * 2)
            base_score += history_points
            
            # Deduct points for late returns
            late_penalty = self.late_returns * 10
            base_score -= late_penalty
            
            # Deduct points for average delay
            delay_penalty = float(self.average_return_delay) * 5
            base_score -= delay_penalty
            
            # Ensure score is within bounds
            self.credit_score = max(0, min(1000, base_score))
        
        # Set reliability rating
        self._set_reliability_rating()
        
        # Update borrowing privileges
        self._update_privileges()
        
        self.save()
    
    def _set_reliability_rating(self):
        """Set reliability rating based on credit score."""
        score = float(self.credit_score)
        if score >= 900:
            self.reliability_rating = 'Excellent'
        elif score >= 800:
            self.reliability_rating = 'Very Good'
        elif score >= 700:
            self.reliability_rating = 'Good'
        elif score >= 600:
            self.reliability_rating = 'Fair'
        elif score >= 500:
            self.reliability_rating = 'Poor'
        else:
            self.reliability_rating = 'Very Poor'
    
    def _update_privileges(self):
        """Update user privileges based on credit score."""
        score = float(self.credit_score)
        
        # Update max books allowed
        if score >= 900:
            self.max_books_allowed = 20
        elif score >= 800:
            self.max_books_allowed = 15
        elif score >= 700:
            self.max_books_allowed = 10
        elif score >= 600:
            self.max_books_allowed = 7
        elif score >= 500:
            self.max_books_allowed = 5
        else:
            self.max_books_allowed = 3
        
        # Update cross-system privileges
        self.system_privileges = {
            'library': {
                'max_books': self.max_books_allowed,
                'renewal_allowed': score >= 600,
                'express_checkout': score >= 800,
                'priority_reservations': score >= 900,
            },
            'bike_rental': {
                'max_duration_hours': 48 if score >= 800 else 24,
                'security_deposit_reduction': 50 if score >= 700 else 0,
                'instant_approval': score >= 750,
            },
            'equipment_rental': {
                'allowed': score >= 600,
                'max_items': 3 if score >= 800 else 1,
                'extended_period': score >= 700,
            }
        }
    
    def sync_external_score(self, system_name, score, metadata=None):
        """
        Sync credit score from an external system.
        
        Args:
            system_name: Name of the external system
            score: Credit score from that system (0-1000 scale)
            metadata: Additional data from the system
        """
        self.external_system_scores[system_name] = {
            'score': float(score),
            'last_updated': timezone.now().isoformat(),
            'metadata': metadata or {}
        }
        self.last_cross_sync = timezone.now()
        self.calculate_composite_score()
        self.save()
    
    def calculate_composite_score(self):
        """
        Calculate composite score across all systems.
        """
        scores = [float(self.credit_score)]  # Start with library score
        weights = [0.5]  # Library system has 50% weight
        
        # Add external system scores
        for system, data in self.external_system_scores.items():
            scores.append(data['score'])
            # Each external system gets equal share of remaining 50%
            weight = 0.5 / len(self.external_system_scores)
            weights.append(weight)
        
        # Calculate weighted average
        if scores:
            weighted_sum = sum(s * w for s, w in zip(scores, weights))
            self.composite_score = round(weighted_sum, 2)
        else:
            self.composite_score = self.credit_score
    
    def get_system_score(self, system_name):
        """Get credit score for a specific system."""
        if system_name == 'library':
            return float(self.credit_score)
        return self.external_system_scores.get(system_name, {}).get('score', 0)


class UserActivityLog(models.Model):
    """
    Log user activities for analytics and tracking.
    """
    ACTION_CHOICES = [
        ('login', 'User Login'),
        ('logout', 'User Logout'),
        ('search', 'Book Search'),
        ('view', 'Book View'),
        ('borrow', 'Book Borrow'),
        ('return', 'Book Return'),
        ('renew', 'Book Renewal'),
        ('reserve', 'Book Reservation'),
        ('profile_update', 'Profile Update'),
        ('password_change', 'Password Change'),
    ]
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='activity_logs'
    )
    
    action = models.CharField(
        max_length=50,
        choices=ACTION_CHOICES,
        db_index=True
    )
    
    details = models.JSONField(
        default=dict,
        blank=True,
        help_text="Additional details about the action"
    )
    
    ip_address = models.GenericIPAddressField(
        null=True,
        blank=True,
        help_text="IP address of the user"
    )
    
    user_agent = models.TextField(
        blank=True,
        help_text="User agent string"
    )
    
    timestamp = models.DateTimeField(
        auto_now_add=True,
        db_index=True
    )
    
    class Meta:
        db_table = 'user_activity_logs'
        verbose_name = 'User Activity Log'
        verbose_name_plural = 'User Activity Logs'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['user', 'action']),
            models.Index(fields=['timestamp']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.action} at {self.timestamp}"


class SystemAnalytics(models.Model):
    """
    System-wide analytics and metrics.
    """
    date = models.DateField(
        unique=True,
        db_index=True,
        help_text="Date for these analytics"
    )
    
    # User metrics
    total_users = models.PositiveIntegerField(default=0)
    active_users = models.PositiveIntegerField(
        default=0,
        help_text="Users who logged in on this date"
    )
    new_registrations = models.PositiveIntegerField(default=0)
    
    # Book metrics
    total_books = models.PositiveIntegerField(default=0)
    available_books = models.PositiveIntegerField(default=0)
    books_borrowed = models.PositiveIntegerField(
        default=0,
        help_text="Number of books borrowed on this date"
    )
    books_returned = models.PositiveIntegerField(
        default=0,
        help_text="Number of books returned on this date"
    )
    
    # Transaction metrics
    total_transactions = models.PositiveIntegerField(default=0)
    overdue_books = models.PositiveIntegerField(default=0)
    late_fees_collected = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00
    )
    
    # Popular categories
    popular_categories = models.JSONField(
        default=list,
        blank=True,
        help_text="Top 10 popular categories"
    )
    
    # Popular books
    popular_books = models.JSONField(
        default=list,
        blank=True,
        help_text="Top 10 popular books"
    )
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'system_analytics'
        verbose_name = 'System Analytics'
        verbose_name_plural = 'System Analytics'
        ordering = ['-date']
    
    def __str__(self):
        return f"Analytics for {self.date}"
    
    @classmethod
    def generate_daily_analytics(cls, date=None):
        """
        Generate analytics for a specific date.
        """
        from django.contrib.auth import get_user_model
        from books.models import Book, BorrowingRecord, BookCategory
        from django.db.models import Count, Sum
        
        if date is None:
            date = timezone.now().date()
        
        User = get_user_model()
        
        # Get or create analytics record
        analytics, created = cls.objects.get_or_create(date=date)
        
        # User metrics
        analytics.total_users = User.objects.filter(is_active=True).count()
        analytics.active_users = UserActivityLog.objects.filter(
            action='login',
            timestamp__date=date
        ).values('user').distinct().count()
        analytics.new_registrations = User.objects.filter(
            date_joined__date=date
        ).count()
        
        # Book metrics
        analytics.total_books = Book.objects.filter(is_active=True).count()
        analytics.available_books = Book.objects.filter(
            is_active=True,
            available_copies__gt=0
        ).count()
        
        # Transaction metrics for the date
        borrowings = BorrowingRecord.objects.filter(borrow_date__date=date)
        returns = BorrowingRecord.objects.filter(return_date__date=date)
        
        analytics.books_borrowed = borrowings.count()
        analytics.books_returned = returns.count()
        analytics.total_transactions = analytics.books_borrowed + analytics.books_returned
        
        # Overdue books
        analytics.overdue_books = BorrowingRecord.objects.filter(
            status='borrowed',
            due_date__lt=timezone.now()
        ).count()
        
        # Late fees
        analytics.late_fees_collected = returns.aggregate(
            total=Sum('late_fees')
        )['total'] or 0
        
        # Popular categories (top 10)
        popular_cats = borrowings.values(
            'book__category__name'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:10]
        
        analytics.popular_categories = [
            {'name': cat['book__category__name'], 'count': cat['count']}
            for cat in popular_cats if cat['book__category__name']
        ]
        
        # Popular books (top 10)
        popular_books = borrowings.values(
            'book__title',
            'book__author'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:10]
        
        analytics.popular_books = [
            {
                'title': book['book__title'],
                'author': book['book__author'],
                'count': book['count']
            }
            for book in popular_books
        ]
        
        analytics.save()
        return analytics
