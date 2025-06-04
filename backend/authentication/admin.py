"""
Admin configuration for the authentication app.
"""
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.translation import gettext_lazy as _
from authentication.models import CustomUser


@admin.register(CustomUser)
class CustomUserAdmin(BaseUserAdmin):
    """
    Admin interface for CustomUser model.
    """
    list_display = (
        'username', 'email', 'full_name', 'user_type', 
        'max_books_allowed', 'is_active', 'email_verified',
        'is_idcs_user', 'last_login_date'
    )
    list_filter = (
        'user_type', 'is_active', 'is_staff', 'is_superuser',
        'email_verified', 'phone_verified', 'mfa_enabled',
        'registration_date'
    )
    search_fields = (
        'username', 'email', 'first_name', 'last_name',
        'phone_number', 'idcs_user_id'
    )
    ordering = ('-registration_date',)
    
    fieldsets = BaseUserAdmin.fieldsets + (
        (_('Library Information'), {
            'fields': (
                'user_type', 'max_books_allowed', 'phone_number',
                'backup_email', 'registration_date', 'last_login_date'
            )
        }),
        (_('Verification Status'), {
            'fields': ('email_verified', 'phone_verified', 'mfa_enabled')
        }),
        (_('Oracle IDCS Integration'), {
            'fields': (
                'idcs_user_id', 'idcs_guid', 'idcs_last_sync', 'idcs_groups'
            ),
            'classes': ('collapse',)
        }),
    )
    
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        (_('Library Information'), {
            'fields': (
                'email', 'user_type', 'max_books_allowed',
                'phone_number', 'first_name', 'last_name'
            )
        }),
    )
    
    readonly_fields = (
        'registration_date', 'last_login_date', 'idcs_last_sync',
        'created_at', 'updated_at'
    )
    
    def full_name(self, obj):
        """Display user's full name."""
        return obj.get_full_name() or '-'
    full_name.short_description = 'Full Name'
    
    def is_idcs_user(self, obj):
        """Check if user is synced with IDCS."""
        return obj.is_idcs_user
    is_idcs_user.boolean = True
    is_idcs_user.short_description = 'IDCS User'
    
    actions = ['sync_with_idcs', 'verify_email', 'reset_borrowing_limit']
    
    def sync_with_idcs(self, request, queryset):
        """Sync selected users with Oracle IDCS."""
        count = 0
        for user in queryset:
            user.sync_with_idcs()
            count += 1
        self.message_user(
            request,
            f'{count} user(s) synced with IDCS.'
        )
    sync_with_idcs.short_description = 'Sync with Oracle IDCS'
    
    def verify_email(self, request, queryset):
        """Mark selected users' emails as verified."""
        count = queryset.update(email_verified=True)
        self.message_user(
            request,
            f'{count} user(s) marked as email verified.'
        )
    verify_email.short_description = 'Mark email as verified'
    
    def reset_borrowing_limit(self, request, queryset):
        """Reset borrowing limit to default based on user type."""
        for user in queryset:
            if user.user_type == 'student':
                user.max_books_allowed = 5
            elif user.user_type == 'faculty':
                user.max_books_allowed = 10
            elif user.user_type == 'staff':
                user.max_books_allowed = 7
            else:  # admin
                user.max_books_allowed = 20
            user.save()
        self.message_user(
            request,
            f'{queryset.count()} user(s) borrowing limits reset.'
        )
    reset_borrowing_limit.short_description = 'Reset borrowing limits'
