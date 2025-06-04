"""
Book management models for the library system.
"""
from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from django.conf import settings
import uuid


class BookCategory(models.Model):
    """
    Categories for organizing books.
    """
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    parent = models.ForeignKey(
        'self',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='subcategories'
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'book_categories'
        verbose_name = 'Book Category'
        verbose_name_plural = 'Book Categories'
        ordering = ['name']
    
    def __str__(self):
        if self.parent:
            return f"{self.parent.name} > {self.name}"
        return self.name


class Book(models.Model):
    """
    Book model representing library books (simplified for demo - no images).
    """
    book_id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    isbn = models.CharField(
        max_length=13,
        unique=True,
        help_text="ISBN-10 or ISBN-13"
    )
    
    title = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Book title"
    )
    
    author = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Primary author name"
    )
    
    category = models.ForeignKey(
        BookCategory,
        on_delete=models.SET_NULL,
        null=True,
        related_name='books'
    )
    
    subcategory = models.ForeignKey(
        BookCategory,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='subcategory_books'
    )
    
    publication_year = models.PositiveIntegerField(
        validators=[
            MinValueValidator(1000),
            MaxValueValidator(9999)
        ],
        help_text="Year of publication"
    )
    
    publisher = models.CharField(
        max_length=255,
        blank=True,
        help_text="Publisher name"
    )
    
    description = models.TextField(
        blank=True,
        help_text="Book description or summary"
    )
    
    total_copies = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)],
        help_text="Total number of copies in the library"
    )
    
    available_copies = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(0)],
        help_text="Number of copies currently available"
    )
    
    location = models.CharField(
        max_length=100,
        blank=True,
        help_text="Physical location in the library (e.g., Shelf A-123)"
    )
    
    # Metadata
    created_date = models.DateTimeField(auto_now_add=True)
    updated_date = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this book is currently available in the catalog"
    )
    
    class Meta:
        db_table = 'books'
        verbose_name = 'Book'
        verbose_name_plural = 'Books'
        ordering = ['title']
        indexes = [
            models.Index(fields=['isbn']),
            models.Index(fields=['title']),
            models.Index(fields=['author']),
            models.Index(fields=['category']),
            models.Index(fields=['is_active', 'available_copies']),
        ]
    
    def __str__(self):
        return f"{self.title} by {self.author}"
    
    def save(self, *args, **kwargs):
        """Ensure available copies doesn't exceed total copies."""
        if self.available_copies > self.total_copies:
            self.available_copies = self.total_copies
        super().save(*args, **kwargs)
    
    @property
    def is_available(self):
        """Check if the book is available for borrowing."""
        return self.is_active and self.available_copies > 0
    
    def borrow(self):
        """Decrease available copies when a book is borrowed."""
        if self.available_copies > 0:
            self.available_copies -= 1
            self.save(update_fields=['available_copies', 'updated_date'])
            return True
        return False
    
    def return_book(self):
        """Increase available copies when a book is returned."""
        if self.available_copies < self.total_copies:
            self.available_copies += 1
            self.save(update_fields=['available_copies', 'updated_date'])
            return True
        return False


class BorrowingRecord(models.Model):
    """
    Record of book borrowing transactions.
    """
    STATUS_CHOICES = [
        ('borrowed', 'Borrowed'),
        ('returned', 'Returned'),
        ('overdue', 'Overdue'),
        ('renewed', 'Renewed'),
        ('lost', 'Lost'),
    ]
    
    record_id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='borrowing_records'
    )
    
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='borrowing_records'
    )
    
    borrow_date = models.DateTimeField(
        default=timezone.now,
        help_text="Date and time when the book was borrowed"
    )
    
    due_date = models.DateTimeField(
        help_text="Date and time when the book should be returned"
    )
    
    return_date = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Actual date and time when the book was returned"
    )
    
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='borrowed',
        db_index=True
    )
    
    late_fees = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Late fees accumulated"
    )
    
    renewal_count = models.PositiveIntegerField(
        default=0,
        help_text="Number of times this borrowing has been renewed"
    )
    
    max_renewals = models.PositiveIntegerField(
        default=2,
        help_text="Maximum number of renewals allowed"
    )
    
    reminder_sent = models.BooleanField(
        default=False,
        help_text="Whether a reminder email has been sent"
    )
    
    notes = models.TextField(
        blank=True,
        help_text="Additional notes about this borrowing"
    )
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'borrowing_records'
        verbose_name = 'Borrowing Record'
        verbose_name_plural = 'Borrowing Records'
        ordering = ['-borrow_date']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['book', 'status']),
            models.Index(fields=['due_date']),
            models.Index(fields=['status', 'due_date']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.book.title} ({self.status})"
    
    def save(self, *args, **kwargs):
        """Set due date if not provided."""
        if not self.due_date:
            from django.conf import settings
            days = getattr(settings, 'MAX_BORROW_DAYS', 14)
            self.due_date = self.borrow_date + timezone.timedelta(days=days)
        super().save(*args, **kwargs)
    
    @property
    def is_overdue(self):
        """Check if the book is overdue."""
        if self.status == 'returned':
            return False
        return timezone.now() > self.due_date
    
    @property
    def days_overdue(self):
        """Calculate number of days overdue."""
        if not self.is_overdue:
            return 0
        if self.return_date:
            delta = self.return_date - self.due_date
        else:
            delta = timezone.now() - self.due_date
        return max(0, delta.days)
    
    def calculate_late_fee(self):
        """Calculate late fee based on days overdue."""
        from library_system.utils import calculate_late_fee
        return calculate_late_fee(self.days_overdue)
    
    def can_renew(self):
        """Check if this borrowing can be renewed."""
        return (
            self.status == 'borrowed' and
            self.renewal_count < self.max_renewals and
            not self.is_overdue
        )
    
    def renew(self):
        """Renew the borrowing for another period."""
        if self.can_renew():
            from django.conf import settings
            days = getattr(settings, 'MAX_BORROW_DAYS', 14)
            self.due_date = timezone.now() + timezone.timedelta(days=days)
            self.renewal_count += 1
            self.status = 'renewed'
            self.save()
            return True
        return False
    
    def return_book(self):
        """Mark the book as returned."""
        self.return_date = timezone.now()
        self.status = 'returned'
        self.late_fees = self.calculate_late_fee()
        self.save()
        
        # Update book availability
        self.book.return_book()
        
        # Update user credit score
        from analytics.tasks import update_user_credit_score
        update_user_credit_score.delay(self.user.id, self.record_id)
    
    def process_return(self, condition_notes=''):
        """Process the return of a book with optional condition notes."""
        self.return_date = timezone.now()
        self.status = 'returned'
        self.late_fees = self.calculate_late_fee()
        
        # Add condition notes if provided
        if condition_notes:
            self.notes += f"\nReturn condition: {condition_notes}"
        
        self.save()
        
        # Update book availability
        self.book.return_book()


class BookStatistics(models.Model):
    """
    Statistical data for books to track popularity and usage.
    """
    book = models.OneToOneField(
        Book,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='statistics'
    )
    
    total_borrowed_count = models.PositiveIntegerField(
        default=0,
        help_text="Total number of times this book has been borrowed"
    )
    
    current_borrowed_count = models.PositiveIntegerField(
        default=0,
        help_text="Number of copies currently borrowed"
    )
    
    average_borrowing_duration = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0.00,
        help_text="Average duration in days that this book is borrowed"
    )
    
    popularity_score = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0.00,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Popularity score from 0 to 100"
    )
    
    last_borrowed_date = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Date when this book was last borrowed"
    )
    
    last_updated = models.DateTimeField(
        auto_now=True,
        help_text="Last time these statistics were updated"
    )
    
    class Meta:
        db_table = 'book_statistics'
        verbose_name = 'Book Statistics'
        verbose_name_plural = 'Book Statistics'
        ordering = ['-popularity_score']
    
    def __str__(self):
        return f"Statistics for {self.book.title}"
    
    def update_statistics(self):
        """
        Update statistics based on borrowing records.
        """
        from django.db.models import Avg, Count, Max
        
        records = BorrowingRecord.objects.filter(book=self.book)
        
        # Update counts
        self.total_borrowed_count = records.count()
        self.current_borrowed_count = records.filter(status='borrowed').count()
        
        # Calculate average duration
        returned_records = records.filter(status='returned', return_date__isnull=False)
        if returned_records.exists():
            durations = []
            for record in returned_records:
                duration = (record.return_date - record.borrow_date).days
                durations.append(duration)
            self.average_borrowing_duration = sum(durations) / len(durations)
        
        # Update last borrowed date
        last_record = records.order_by('-borrow_date').first()
        if last_record:
            self.last_borrowed_date = last_record.borrow_date
        
        # Calculate popularity score (simple algorithm)
        # Based on: borrow count, recency, and availability
        if self.total_borrowed_count > 0:
            recency_score = 0
            if self.last_borrowed_date:
                days_since_borrowed = (timezone.now() - self.last_borrowed_date).days
                recency_score = max(0, 100 - days_since_borrowed)
            
            borrow_score = min(100, self.total_borrowed_count * 5)
            availability_penalty = 0 if self.book.available_copies > 0 else 20
            
            self.popularity_score = min(100, (borrow_score + recency_score) / 2 - availability_penalty)
        
        self.save()
