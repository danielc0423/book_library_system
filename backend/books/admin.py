"""
Admin configuration for the books app.
"""
from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from books.models import Book, BookCategory, BorrowingRecord, BookStatistics


@admin.register(BookCategory)
class BookCategoryAdmin(admin.ModelAdmin):
    """
    Admin interface for BookCategory model.
    """
    list_display = ('name', 'parent', 'description', 'is_active', 'book_count')
    list_filter = ('is_active', 'parent')
    search_fields = ('name', 'description')
    ordering = ('name',)
    
    def book_count(self, obj):
        """Count of books in this category."""
        return obj.books.count()
    book_count.short_description = 'Books'


@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    """
    Admin interface for Book model.
    """
    list_display = (
        'title', 'author', 'isbn', 'category', 'publication_year',
        'availability_status', 'total_copies', 'available_copies',
        'is_active'
    )
    list_filter = (
        'is_active', 'category', 'publication_year',
        'available_copies'  # Removed EmptyFieldListFilter for non-nullable field
    )
    search_fields = ('title', 'author', 'isbn', 'publisher', 'description')
    ordering = ('title',)
    date_hierarchy = 'created_date'
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('isbn', 'title', 'author', 'publisher', 'publication_year')
        }),
        ('Classification', {
            'fields': ('category', 'subcategory', 'description')
        }),
        ('Inventory', {
            'fields': ('total_copies', 'available_copies', 'location')
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
        ('Metadata', {
            'fields': ('book_id', 'created_date', 'updated_date'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ('book_id', 'created_date', 'updated_date')
    
    def availability_status(self, obj):
        """Display availability status with color coding."""
        if not obj.is_active:
            return format_html(
                '<span style="color: red;">Inactive</span>'
            )
        elif obj.available_copies == 0:
            return format_html(
                '<span style="color: red;">Out of Stock</span>'
            )
        elif obj.available_copies < 3:
            return format_html(
                '<span style="color: orange;">Low Stock ({} left)</span>',
                obj.available_copies
            )
        else:
            return format_html(
                '<span style="color: green;">Available ({} copies)</span>',
                obj.available_copies
            )
    availability_status.short_description = 'Availability'
    
    actions = ['make_active', 'make_inactive', 'update_statistics']
    
    def make_active(self, request, queryset):
        """Activate selected books."""
        count = queryset.update(is_active=True)
        self.message_user(request, f'{count} book(s) activated.')
    make_active.short_description = 'Activate selected books'
    
    def make_inactive(self, request, queryset):
        """Deactivate selected books."""
        count = queryset.update(is_active=False)
        self.message_user(request, f'{count} book(s) deactivated.')
    make_inactive.short_description = 'Deactivate selected books'
    
    def update_statistics(self, request, queryset):
        """Update statistics for selected books."""
        count = 0
        for book in queryset:
            if hasattr(book, 'statistics'):
                book.statistics.update_statistics()
                count += 1
        self.message_user(request, f'Statistics updated for {count} book(s).')
    update_statistics.short_description = 'Update book statistics'


@admin.register(BorrowingRecord)
class BorrowingRecordAdmin(admin.ModelAdmin):
    """
    Admin interface for BorrowingRecord model.
    """
    list_display = (
        'record_number', 'user_link', 'book_link', 'status',
        'borrow_date', 'due_date', 'return_date', 'days_overdue_display',
        'late_fees', 'renewal_count'
    )
    list_filter = (
        'status', 'reminder_sent',
        ('borrow_date', admin.DateFieldListFilter),
        ('due_date', admin.DateFieldListFilter),
        ('return_date', admin.DateFieldListFilter)
    )
    search_fields = (
        'user__username', 'user__email', 'user__first_name',
        'user__last_name', 'book__title', 'book__isbn'
    )
    ordering = ('-borrow_date',)
    date_hierarchy = 'borrow_date'
    
    fieldsets = (
        ('User & Book', {
            'fields': ('user', 'book')
        }),
        ('Dates', {
            'fields': ('borrow_date', 'due_date', 'return_date')
        }),
        ('Status', {
            'fields': ('status', 'late_fees', 'reminder_sent')
        }),
        ('Renewal', {
            'fields': ('renewal_count', 'max_renewals')
        }),
        ('Notes', {
            'fields': ('notes',),
            'classes': ('collapse',)
        }),
        ('Metadata', {
            'fields': ('record_id', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = (
        'record_id', 'created_at', 'updated_at', 'late_fees'
    )
    
    def record_number(self, obj):
        """Display shortened record ID."""
        return str(obj.record_id)[:8] + '...'
    record_number.short_description = 'Record #'
    
    def user_link(self, obj):
        """Link to user admin page."""
        return format_html(
            '<a href="/admin/authentication/customuser/{}/change/">{}</a>',
            obj.user.id,
            obj.user.username
        )
    user_link.short_description = 'User'
    
    def book_link(self, obj):
        """Link to book admin page."""
        return format_html(
            '<a href="/admin/books/book/{}/change/">{}</a>',
            obj.book.book_id,
            obj.book.title[:50] + '...' if len(obj.book.title) > 50 else obj.book.title
        )
    book_link.short_description = 'Book'
    
    def days_overdue_display(self, obj):
        """Display days overdue with color coding."""
        days = obj.days_overdue
        if days == 0:
            return '-'
        elif days < 7:
            return format_html(
                '<span style="color: orange;">{} days</span>',
                days
            )
        else:
            return format_html(
                '<span style="color: red; font-weight: bold;">{} days</span>',
                days
            )
    days_overdue_display.short_description = 'Overdue'
    
    actions = ['mark_as_returned', 'send_reminder', 'calculate_fees']
    
    def mark_as_returned(self, request, queryset):
        """Mark selected records as returned."""
        count = 0
        for record in queryset.filter(status='borrowed'):
            record.return_book()
            count += 1
        self.message_user(request, f'{count} book(s) marked as returned.')
    mark_as_returned.short_description = 'Mark as returned'
    
    def send_reminder(self, request, queryset):
        """Send reminder for selected borrowing records."""
        from notifications.models import NotificationQueue
        count = 0
        for record in queryset.filter(status='borrowed', reminder_sent=False):
            NotificationQueue.objects.create(
                user=record.user,
                notification_type='pre_due_reminder',
                scheduled_for=timezone.now(),
                priority='high',
                data={
                    'book_title': record.book.title,
                    'due_date': record.due_date.strftime('%Y-%m-%d')
                }
            )
            record.reminder_sent = True
            record.save()
            count += 1
        self.message_user(request, f'Reminders sent for {count} record(s).')
    send_reminder.short_description = 'Send reminder email'
    
    def calculate_fees(self, request, queryset):
        """Calculate late fees for selected records."""
        count = 0
        total_fees = 0
        for record in queryset:
            fee = record.calculate_late_fee()
            if fee > 0:
                record.late_fees = fee
                record.save()
                count += 1
                total_fees += fee
        self.message_user(
            request,
            f'Late fees calculated for {count} record(s). Total: ${total_fees:.2f}'
        )
    calculate_fees.short_description = 'Calculate late fees'


@admin.register(BookStatistics)
class BookStatisticsAdmin(admin.ModelAdmin):
    """
    Admin interface for BookStatistics model.
    """
    list_display = (
        'book_title', 'total_borrowed_count', 'current_borrowed_count',
        'average_borrowing_duration', 'popularity_score', 'last_borrowed_date'
    )
    list_filter = (
        ('last_borrowed_date', admin.DateFieldListFilter),
        'popularity_score'  # Removed EmptyFieldListFilter for non-nullable field
    )
    search_fields = ('book__title', 'book__isbn', 'book__author')
    ordering = ('-popularity_score', '-total_borrowed_count')
    
    readonly_fields = (
        'book', 'total_borrowed_count', 'current_borrowed_count',
        'average_borrowing_duration', 'popularity_score',
        'last_borrowed_date', 'last_updated'
    )
    
    def book_title(self, obj):
        """Display book title."""
        return obj.book.title
    book_title.short_description = 'Book'
    book_title.admin_order_field = 'book__title'
    
    def has_add_permission(self, request):
        """Statistics are auto-created, not manually added."""
        return False
    
    actions = ['refresh_statistics']
    
    def refresh_statistics(self, request, queryset):
        """Refresh statistics for selected books."""
        count = 0
        for stat in queryset:
            stat.update_statistics()
            count += 1
        self.message_user(request, f'Statistics refreshed for {count} book(s).')
    refresh_statistics.short_description = 'Refresh statistics'
