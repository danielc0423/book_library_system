"""
Admin configuration for the notifications app.
"""
from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from notifications.models import (
    NotificationTemplate, NotificationLog, NotificationPreference,
    NotificationQueue
)


@admin.register(NotificationTemplate)
class NotificationTemplateAdmin(admin.ModelAdmin):
    """
    Admin interface for NotificationTemplate model.
    """
    list_display = (
        'name', 'template_type', 'subject', 'is_active',
        'variables_count', 'updated_at'
    )
    list_filter = ('template_type', 'is_active')
    search_fields = ('name', 'subject', 'html_template', 'text_template')
    ordering = ('template_type', 'name')
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('name', 'template_type', 'subject', 'is_active')
        }),
        ('Templates', {
            'fields': ('html_template', 'text_template')
        }),
        ('Configuration', {
            'fields': ('variables',),
            'description': 'List of available template variables that can be used'
        }),
        ('Metadata', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ('created_at', 'updated_at')
    
    def variables_count(self, obj):
        """Count of template variables."""
        return len(obj.variables) if obj.variables else 0
    variables_count.short_description = 'Variables'
    
    actions = ['activate_templates', 'deactivate_templates', 'test_template']
    
    def activate_templates(self, request, queryset):
        """Activate selected templates."""
        count = queryset.update(is_active=True)
        self.message_user(request, f'{count} template(s) activated.')
    activate_templates.short_description = 'Activate selected templates'
    
    def deactivate_templates(self, request, queryset):
        """Deactivate selected templates."""
        count = queryset.update(is_active=False)
        self.message_user(request, f'{count} template(s) deactivated.')
    deactivate_templates.short_description = 'Deactivate selected templates'
    
    def test_template(self, request, queryset):
        """Send test email using selected template."""
        # This would send a test email to admin
        self.message_user(request, 'Test email functionality not implemented yet.')
    test_template.short_description = 'Send test email'


@admin.register(NotificationLog)
class NotificationLogAdmin(admin.ModelAdmin):
    """
    Admin interface for NotificationLog model.
    """
    list_display = (
        'notification_id_short', 'user_link', 'notification_type',
        'subject_truncated', 'status_display', 'sent_at', 'created_at'
    )
    list_filter = (
        'status', 'notification_type',
        ('sent_at', admin.DateFieldListFilter),
        ('created_at', admin.DateFieldListFilter)
    )
    search_fields = (
        'user__username', 'user__email', 'subject',
        'recipient_email', 'notification_id'
    )
    ordering = ('-created_at',)
    date_hierarchy = 'created_at'
    
    fieldsets = (
        ('Notification Details', {
            'fields': (
                'notification_id', 'user', 'template',
                'notification_type', 'subject', 'recipient_email'
            )
        }),
        ('Status', {
            'fields': ('status', 'sent_at', 'error_message')
        }),
        ('Content', {
            'fields': ('metadata',),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = (
        'notification_id', 'user', 'template', 'notification_type',
        'subject', 'recipient_email', 'sent_at', 'error_message',
        'metadata', 'created_at', 'updated_at'
    )
    
    def notification_id_short(self, obj):
        """Display shortened notification ID."""
        return str(obj.notification_id)[:8] + '...'
    notification_id_short.short_description = 'ID'
    
    def user_link(self, obj):
        """Link to user admin page."""
        return format_html(
            '<a href="/admin/authentication/customuser/{}/change/">{}</a>',
            obj.user.id,
            obj.user.username
        )
    user_link.short_description = 'User'
    
    def subject_truncated(self, obj):
        """Truncated subject line."""
        return obj.subject[:50] + '...' if len(obj.subject) > 50 else obj.subject
    subject_truncated.short_description = 'Subject'
    
    def status_display(self, obj):
        """Display status with color coding."""
        colors = {
            'pending': 'orange',
            'sent': 'green',
            'failed': 'red',
            'bounced': 'darkred'
        }
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            colors.get(obj.status, 'black'),
            obj.get_status_display()
        )
    status_display.short_description = 'Status'
    
    def has_add_permission(self, request):
        """Notification logs are auto-generated."""
        return False
    
    def has_change_permission(self, request, obj=None):
        """Notification logs should not be edited."""
        return False
    
    actions = ['resend_notification', 'mark_as_sent']
    
    def resend_notification(self, request, queryset):
        """Resend failed notifications."""
        count = 0
        for log in queryset.filter(status__in=['failed', 'bounced']):
            log.status = 'pending'
            log.save()
            log.send()
            count += 1
        self.message_user(request, f'{count} notification(s) queued for resending.')
    resend_notification.short_description = 'Resend failed notifications'
    
    def mark_as_sent(self, request, queryset):
        """Mark notifications as sent (for testing)."""
        count = queryset.update(status='sent', sent_at=timezone.now())
        self.message_user(request, f'{count} notification(s) marked as sent.')
    mark_as_sent.short_description = 'Mark as sent'


@admin.register(NotificationPreference)
class NotificationPreferenceAdmin(admin.ModelAdmin):
    """
    Admin interface for NotificationPreference model.
    """
    list_display = (
        'user_link', 'email_enabled', 'borrow_confirmation',
        'return_confirmation', 'pre_due_reminder', 'overdue_notice',
        'credit_score_updates', 'newsletter', 'quiet_hours'
    )
    list_filter = (
        'email_enabled', 'newsletter', 'borrow_confirmation',
        'return_confirmation', 'pre_due_reminder', 'overdue_notice'
    )
    search_fields = ('user__username', 'user__email')
    ordering = ('user__username',)
    
    fieldsets = (
        ('User', {
            'fields': ('user',)
        }),
        ('Email Preferences', {
            'fields': (
                'email_enabled', 'welcome_email', 'borrow_confirmation',
                'return_confirmation', 'pre_due_reminder', 'overdue_notice',
                'credit_score_updates', 'newsletter'
            )
        }),
        ('Timing Preferences', {
            'fields': (
                'reminder_days_before', 'quiet_hours_start', 'quiet_hours_end'
            )
        }),
        ('Metadata', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ('user', 'created_at', 'updated_at')
    
    def user_link(self, obj):
        """Link to user admin page."""
        return format_html(
            '<a href="/admin/authentication/customuser/{}/change/">{}</a>',
            obj.user.id,
            obj.user.username
        )
    user_link.short_description = 'User'
    
    def quiet_hours(self, obj):
        """Display quiet hours."""
        return f"{obj.quiet_hours_start} - {obj.quiet_hours_end}"
    quiet_hours.short_description = 'Quiet Hours'
    
    actions = ['enable_all_notifications', 'disable_all_notifications']
    
    def enable_all_notifications(self, request, queryset):
        """Enable all notifications for selected users."""
        count = queryset.update(
            email_enabled=True,
            welcome_email=True,
            borrow_confirmation=True,
            return_confirmation=True,
            pre_due_reminder=True,
            overdue_notice=True,
            credit_score_updates=True
        )
        self.message_user(request, f'All notifications enabled for {count} user(s).')
    enable_all_notifications.short_description = 'Enable all notifications'
    
    def disable_all_notifications(self, request, queryset):
        """Disable all notifications for selected users."""
        count = queryset.update(email_enabled=False)
        self.message_user(request, f'All notifications disabled for {count} user(s).')
    disable_all_notifications.short_description = 'Disable all notifications'


@admin.register(NotificationQueue)
class NotificationQueueAdmin(admin.ModelAdmin):
    """
    Admin interface for NotificationQueue model.
    """
    list_display = (
        'queue_id_short', 'user_link', 'notification_type',
        'scheduled_for_display', 'priority_display', 'is_processed',
        'attempts', 'created_at'
    )
    list_filter = (
        'is_processed', 'priority', 'notification_type',
        ('scheduled_for', admin.DateFieldListFilter),
        ('created_at', admin.DateFieldListFilter)
    )
    search_fields = (
        'user__username', 'user__email', 'notification_type',
        'queue_id'
    )
    ordering = ('is_processed', 'scheduled_for', '-priority')
    date_hierarchy = 'scheduled_for'
    
    fieldsets = (
        ('Queue Details', {
            'fields': (
                'queue_id', 'user', 'notification_type',
                'scheduled_for', 'priority'
            )
        }),
        ('Processing', {
            'fields': (
                'is_processed', 'processed_at', 'attempts',
                'max_attempts', 'error_message'
            )
        }),
        ('Data', {
            'fields': ('data',),
            'classes': ('collapse',)
        }),
        ('Metadata', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = (
        'queue_id', 'processed_at', 'created_at', 'updated_at'
    )
    
    def queue_id_short(self, obj):
        """Display shortened queue ID."""
        return str(obj.queue_id)[:8] + '...'
    queue_id_short.short_description = 'Queue ID'
    
    def user_link(self, obj):
        """Link to user admin page."""
        return format_html(
            '<a href="/admin/authentication/customuser/{}/change/">{}</a>',
            obj.user.id,
            obj.user.username
        )
    user_link.short_description = 'User'
    
    def scheduled_for_display(self, obj):
        """Display scheduled time with color coding."""
        now = timezone.now()
        if obj.is_processed:
            return format_html(
                '<span style="color: gray;">{}</span>',
                obj.scheduled_for.strftime('%Y-%m-%d %H:%M')
            )
        elif obj.scheduled_for < now:
            return format_html(
                '<span style="color: red; font-weight: bold;">Overdue: {}</span>',
                obj.scheduled_for.strftime('%Y-%m-%d %H:%M')
            )
        else:
            return obj.scheduled_for.strftime('%Y-%m-%d %H:%M')
    scheduled_for_display.short_description = 'Scheduled For'
    
    def priority_display(self, obj):
        """Display priority with color coding."""
        colors = {
            'low': 'gray',
            'normal': 'black',
            'high': 'orange',
            'urgent': 'red'
        }
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            colors.get(obj.priority, 'black'),
            obj.get_priority_display()
        )
    priority_display.short_description = 'Priority'
    
    actions = ['process_queue', 'mark_as_processed', 'reschedule']
    
    def process_queue(self, request, queryset):
        """Process selected queue items."""
        count = 0
        for item in queryset.filter(is_processed=False):
            if item.process():
                count += 1
        self.message_user(request, f'{count} notification(s) processed.')
    process_queue.short_description = 'Process selected notifications'
    
    def mark_as_processed(self, request, queryset):
        """Mark items as processed without sending."""
        count = queryset.update(
            is_processed=True,
            processed_at=timezone.now()
        )
        self.message_user(request, f'{count} item(s) marked as processed.')
    mark_as_processed.short_description = 'Mark as processed'
    
    def reschedule(self, request, queryset):
        """Reschedule notifications to run in 5 minutes."""
        new_time = timezone.now() + timezone.timedelta(minutes=5)
        count = queryset.filter(is_processed=False).update(
            scheduled_for=new_time,
            attempts=0
        )
        self.message_user(
            request,
            f'{count} notification(s) rescheduled to {new_time.strftime("%H:%M")}.'
        )
    reschedule.short_description = 'Reschedule for 5 minutes'
