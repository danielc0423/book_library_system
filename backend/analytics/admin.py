"""
Admin configuration for the analytics app.
"""
from django.contrib import admin
from django.utils.html import format_html
from analytics.models import UserCreditScore, UserActivityLog, SystemAnalytics


@admin.register(UserCreditScore)
class UserCreditScoreAdmin(admin.ModelAdmin):
    """
    Admin interface for UserCreditScore model.
    """
    list_display = (
        'user_link', 'credit_score_display', 'reliability_rating',
        'on_time_returns', 'late_returns', 'total_books_borrowed',
        'max_books_allowed', 'composite_score_display', 'last_calculated'
    )
    list_filter = (
        'reliability_rating',
        'credit_score',  # Removed EmptyFieldListFilter for non-nullable field
        'last_calculated'
    )
    search_fields = (
        'user__username', 'user__email', 'user__first_name',
        'user__last_name'
    )
    ordering = ('-credit_score',)
    
    fieldsets = (
        ('User', {
            'fields': ('user',)
        }),
        ('Credit Score', {
            'fields': (
                'credit_score', 'reliability_rating', 'max_books_allowed'
            )
        }),
        ('Library Metrics', {
            'fields': (
                'on_time_returns', 'late_returns', 'total_books_borrowed',
                'average_return_delay'
            )
        }),
        ('Cross-System Integration', {
            'fields': (
                'external_system_scores', 'composite_score',
                'system_privileges', 'last_cross_sync'
            ),
            'classes': ('collapse',)
        }),
        ('Metadata', {
            'fields': ('last_calculated', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = (
        'user', 'last_calculated', 'created_at', 'updated_at',
        'last_cross_sync'
    )
    
    def user_link(self, obj):
        """Link to user admin page."""
        return format_html(
            '<a href="/admin/authentication/customuser/{}/change/">{}</a>',
            obj.user.id,
            obj.user.username
        )
    user_link.short_description = 'User'
    user_link.admin_order_field = 'user__username'
    
    def credit_score_display(self, obj):
        """Display credit score with color coding."""
        try:
            score = float(obj.credit_score)
        except (ValueError, TypeError):
            score = 0.0
            
        if score >= 800:
            color = 'green'
        elif score >= 600:
            color = 'orange'
        else:
            color = 'red'
            
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            color, 
            int(score)  # Convert to int to avoid decimal formatting issues
        )
    credit_score_display.short_description = 'Credit Score'
    credit_score_display.admin_order_field = 'credit_score'
    
    def composite_score_display(self, obj):
        """Display composite score if different from credit score."""
        try:
            credit_score = float(obj.credit_score)
            composite_score = float(obj.composite_score)
        except (ValueError, TypeError):
            return '-'
            
        if composite_score != credit_score:
            return format_html(
                '<span style="color: blue;">{}</span>',
                int(composite_score)
            )
        return '-'
    composite_score_display.short_description = 'Composite'
    
    actions = ['recalculate_scores', 'sync_cross_systems', 'reset_to_default']
    
    def recalculate_scores(self, request, queryset):
        """Recalculate credit scores for selected users."""
        count = 0
        for score in queryset:
            score.calculate_score()
            count += 1
        self.message_user(request, f'Credit scores recalculated for {count} user(s).')
    recalculate_scores.short_description = 'Recalculate credit scores'
    
    def sync_cross_systems(self, request, queryset):
        """Sync credit scores across systems."""
        count = 0
        for score in queryset:
            score.calculate_composite_score()
            score.save()
            count += 1
        self.message_user(request, f'Cross-system sync completed for {count} user(s).')
    sync_cross_systems.short_description = 'Sync across systems'
    
    def reset_to_default(self, request, queryset):
        """Reset credit scores to default value."""
        count = queryset.update(
            credit_score=750,
            reliability_rating='Good',
            on_time_returns=0,
            late_returns=0,
            total_books_borrowed=0,
            average_return_delay=0
        )
        self.message_user(request, f'{count} credit score(s) reset to default.')
    reset_to_default.short_description = 'Reset to default score'
    
    def has_add_permission(self, request):
        """Credit scores are auto-created with users."""
        return False


@admin.register(UserActivityLog)
class UserActivityLogAdmin(admin.ModelAdmin):
    """
    Admin interface for UserActivityLog model.
    """
    list_display = (
        'timestamp', 'user_link', 'action', 'details_summary',
        'ip_address'
    )
    list_filter = (
        'action',
        ('timestamp', admin.DateFieldListFilter),
    )
    search_fields = (
        'user__username', 'user__email', 'ip_address',
        'details'
    )
    ordering = ('-timestamp',)
    date_hierarchy = 'timestamp'
    
    readonly_fields = (
        'user', 'action', 'details', 'ip_address',
        'user_agent', 'timestamp'
    )
    
    def user_link(self, obj):
        """Link to user admin page."""
        return format_html(
            '<a href="/admin/authentication/customuser/{}/change/">{}</a>',
            obj.user.id,
            obj.user.username
        )
    user_link.short_description = 'User'
    user_link.admin_order_field = 'user__username'
    
    def details_summary(self, obj):
        """Summary of activity details."""
        if obj.action == 'borrow' and 'book_title' in obj.details:
            return f"Book: {obj.details['book_title'][:30]}..."
        elif obj.action == 'search' and 'query' in obj.details:
            return f"Query: {obj.details['query']}"
        elif obj.action == 'login':
            return "Successful login"
        return str(obj.details)[:50] + '...' if len(str(obj.details)) > 50 else str(obj.details)
    details_summary.short_description = 'Details'
    
    def has_add_permission(self, request):
        """Activity logs are auto-generated."""
        return False
    
    def has_change_permission(self, request, obj=None):
        """Activity logs should not be edited."""
        return False
    
    actions = ['export_to_csv']
    
    def export_to_csv(self, request, queryset):
        """Export selected logs to CSV."""
        import csv
        from django.http import HttpResponse
        
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="activity_logs.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['Timestamp', 'User', 'Action', 'Details', 'IP Address'])
        
        for log in queryset:
            writer.writerow([
                log.timestamp,
                log.user.username,
                log.action,
                str(log.details),
                log.ip_address or '-'
            ])
        
        return response
    export_to_csv.short_description = 'Export to CSV'


@admin.register(SystemAnalytics)
class SystemAnalyticsAdmin(admin.ModelAdmin):
    """
    Admin interface for SystemAnalytics model.
    """
    list_display = (
        'date', 'total_users', 'active_users', 'new_registrations',
        'books_borrowed', 'books_returned', 'overdue_books',
        'late_fees_collected'
    )
    list_filter = (
        ('date', admin.DateFieldListFilter),
    )
    ordering = ('-date',)
    date_hierarchy = 'date'
    
    fieldsets = (
        ('Date', {
            'fields': ('date',)
        }),
        ('User Metrics', {
            'fields': (
                'total_users', 'active_users', 'new_registrations'
            )
        }),
        ('Book Metrics', {
            'fields': (
                'total_books', 'available_books', 'books_borrowed',
                'books_returned'
            )
        }),
        ('Transaction Metrics', {
            'fields': (
                'total_transactions', 'overdue_books', 'late_fees_collected'
            )
        }),
        ('Popular Items', {
            'fields': ('popular_categories', 'popular_books'),
            'classes': ('collapse',)
        }),
        ('Metadata', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = (
        'date', 'created_at', 'updated_at'
    )
    
    actions = ['generate_analytics', 'export_report']
    
    def generate_analytics(self, request, queryset):
        """Generate analytics for selected dates."""
        count = 0
        for analytics in queryset:
            SystemAnalytics.generate_daily_analytics(analytics.date)
            count += 1
        self.message_user(request, f'Analytics regenerated for {count} date(s).')
    generate_analytics.short_description = 'Regenerate analytics'
    
    def export_report(self, request, queryset):
        """Export analytics report."""
        # This would generate a PDF or Excel report
        self.message_user(request, 'Report generation not implemented yet.')
    export_report.short_description = 'Export analytics report'
    
    def has_add_permission(self, request):
        """Analytics are auto-generated daily."""
        return False
