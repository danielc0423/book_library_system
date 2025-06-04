"""
Notification serializers for the Library System API.
"""
from rest_framework import serializers
from .models import NotificationTemplate, NotificationLog, NotificationPreference, NotificationQueue


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    """Serializer for user notification preferences."""
    class Meta:
        model = NotificationPreference
        fields = ['email_enabled', 'welcome_email', 'borrow_confirmation',
                  'return_confirmation', 'pre_due_reminder', 'overdue_notice',
                  'credit_score_updates', 'newsletter', 'reminder_days_before',
                  'quiet_hours_start', 'quiet_hours_end']
        
    def validate(self, attrs):
        # Validate quiet hours
        if attrs.get('quiet_hours_start') and attrs.get('quiet_hours_end'):
            if attrs['quiet_hours_start'] >= attrs['quiet_hours_end']:
                raise serializers.ValidationError({
                    'quiet_hours_start': 'Start time must be before end time.'
                })
        return attrs


class NotificationLogSerializer(serializers.ModelSerializer):
    """Serializer for notification history."""
    template_name = serializers.CharField(source='template.name', read_only=True)
    
    class Meta:
        model = NotificationLog
        fields = ['id', 'template', 'template_name', 'recipient_email',
                  'subject', 'sent_at', 'status', 'error_message']
        read_only_fields = '__all__'


class NotificationTemplateSerializer(serializers.ModelSerializer):
    """Serializer for notification templates (admin only)."""
    usage_count = serializers.SerializerMethodField()
    
    class Meta:
        model = NotificationTemplate
        fields = ['id', 'name', 'subject', 'body', 'template_type',
                  'is_active', 'created_at', 'updated_at', 'usage_count']
        read_only_fields = ['id', 'created_at', 'updated_at', 'usage_count']
    
    def get_usage_count(self, obj):
        return obj.notification_logs.count()
