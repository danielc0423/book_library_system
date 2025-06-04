"""
Notification models for email alerts and reminders.
"""
from django.db import models
from django.conf import settings
from django.utils import timezone
from django.template.loader import render_to_string
from django.core.mail import send_mail
import uuid


class NotificationTemplate(models.Model):
    """
    Email notification templates.
    """
    TEMPLATE_TYPES = [
        ('welcome', 'Welcome Email'),
        ('borrow_confirmation', 'Borrowing Confirmation'),
        ('return_confirmation', 'Return Confirmation'),
        ('pre_due_reminder', 'Pre-Due Date Reminder'),
        ('overdue_notice', 'Overdue Notice'),
        ('renewal_confirmation', 'Renewal Confirmation'),
        ('credit_score_update', 'Credit Score Update'),
        ('account_suspended', 'Account Suspended'),
        ('password_reset', 'Password Reset'),
        ('email_verification', 'Email Verification'),
    ]
    
    name = models.CharField(
        max_length=100,
        unique=True,
        help_text="Template identifier"
    )
    
    template_type = models.CharField(
        max_length=50,
        choices=TEMPLATE_TYPES,
        unique=True
    )
    
    subject = models.CharField(
        max_length=200,
        help_text="Email subject line"
    )
    
    html_template = models.TextField(
        help_text="HTML email template with variables"
    )
    
    text_template = models.TextField(
        help_text="Plain text email template with variables"
    )
    
    variables = models.JSONField(
        default=list,
        blank=True,
        help_text="List of available template variables"
    )
    
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this template is currently in use"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'notification_templates'
        verbose_name = 'Notification Template'
        verbose_name_plural = 'Notification Templates'
        ordering = ['template_type']
    
    def __str__(self):
        return f"{self.name} ({self.template_type})"


class NotificationLog(models.Model):
    """
    Log of all sent notifications.
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('sent', 'Sent'),
        ('failed', 'Failed'),
        ('bounced', 'Bounced'),
    ]
    
    notification_id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    
    template = models.ForeignKey(
        NotificationTemplate,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    
    notification_type = models.CharField(
        max_length=50,
        db_index=True,
        help_text="Type of notification sent"
    )
    
    subject = models.CharField(
        max_length=200,
        help_text="Email subject"
    )
    
    recipient_email = models.EmailField(
        help_text="Recipient email address"
    )
    
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        db_index=True
    )
    
    sent_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the notification was sent"
    )
    
    error_message = models.TextField(
        blank=True,
        help_text="Error message if sending failed"
    )
    
    metadata = models.JSONField(
        default=dict,
        blank=True,
        help_text="Additional metadata about the notification"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'notification_logs'
        verbose_name = 'Notification Log'
        verbose_name_plural = 'Notification Logs'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['notification_type', 'created_at']),
        ]
    
    def __str__(self):
        return f"{self.notification_type} to {self.user.username} - {self.status}"
    
    def send(self):
        """
        Send the notification email.
        """
        try:
            send_mail(
                subject=self.subject,
                message=self.metadata.get('text_content', ''),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[self.recipient_email],
                html_message=self.metadata.get('html_content', ''),
                fail_silently=False,
            )
            self.status = 'sent'
            self.sent_at = timezone.now()
        except Exception as e:
            self.status = 'failed'
            self.error_message = str(e)
        
        self.save()


class NotificationPreference(models.Model):
    """
    User notification preferences.
    """
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='notification_preferences'
    )
    
    # Email notifications
    email_enabled = models.BooleanField(
        default=True,
        help_text="Enable email notifications"
    )
    
    welcome_email = models.BooleanField(
        default=True,
        help_text="Receive welcome email"
    )
    
    borrow_confirmation = models.BooleanField(
        default=True,
        help_text="Receive borrowing confirmation emails"
    )
    
    return_confirmation = models.BooleanField(
        default=True,
        help_text="Receive return confirmation emails"
    )
    
    pre_due_reminder = models.BooleanField(
        default=True,
        help_text="Receive reminders before due date"
    )
    
    overdue_notice = models.BooleanField(
        default=True,
        help_text="Receive overdue notices"
    )
    
    credit_score_updates = models.BooleanField(
        default=True,
        help_text="Receive credit score change notifications"
    )
    
    newsletter = models.BooleanField(
        default=False,
        help_text="Subscribe to library newsletter"
    )
    
    # Notification timing preferences
    reminder_days_before = models.PositiveIntegerField(
        default=3,
        help_text="Days before due date to send reminder"
    )
    
    quiet_hours_start = models.TimeField(
        default='22:00',
        help_text="Start of quiet hours (no notifications)"
    )
    
    quiet_hours_end = models.TimeField(
        default='08:00',
        help_text="End of quiet hours"
    )
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'notification_preferences'
        verbose_name = 'Notification Preference'
        verbose_name_plural = 'Notification Preferences'
    
    def __str__(self):
        return f"Notification preferences for {self.user.username}"
    
    def can_send_notification(self, notification_type):
        """
        Check if a notification can be sent based on preferences.
        """
        if not self.email_enabled:
            return False
        
        # Check specific notification type preferences
        preference_map = {
            'welcome': self.welcome_email,
            'borrow_confirmation': self.borrow_confirmation,
            'return_confirmation': self.return_confirmation,
            'pre_due_reminder': self.pre_due_reminder,
            'overdue_notice': self.overdue_notice,
            'credit_score_update': self.credit_score_updates,
            'newsletter': self.newsletter,
        }
        
        return preference_map.get(notification_type, True)
    
    def is_quiet_hours(self):
        """
        Check if current time is within quiet hours.
        """
        now = timezone.now().time()
        
        # Handle case where quiet hours span midnight
        if self.quiet_hours_start > self.quiet_hours_end:
            return now >= self.quiet_hours_start or now <= self.quiet_hours_end
        else:
            return self.quiet_hours_start <= now <= self.quiet_hours_end


class NotificationQueue(models.Model):
    """
    Queue for scheduled notifications.
    """
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('normal', 'Normal'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ]
    
    queue_id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notification_queue'
    )
    
    notification_type = models.CharField(
        max_length=50,
        help_text="Type of notification to send"
    )
    
    scheduled_for = models.DateTimeField(
        db_index=True,
        help_text="When to send this notification"
    )
    
    priority = models.CharField(
        max_length=20,
        choices=PRIORITY_CHOICES,
        default='normal'
    )
    
    data = models.JSONField(
        default=dict,
        help_text="Data for the notification"
    )
    
    attempts = models.PositiveIntegerField(
        default=0,
        help_text="Number of send attempts"
    )
    
    max_attempts = models.PositiveIntegerField(
        default=3,
        help_text="Maximum send attempts"
    )
    
    is_processed = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Whether this notification has been processed"
    )
    
    processed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When this notification was processed"
    )
    
    error_message = models.TextField(
        blank=True,
        help_text="Error message if processing failed"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'notification_queue'
        verbose_name = 'Notification Queue'
        verbose_name_plural = 'Notification Queue'
        ordering = ['scheduled_for', '-priority']
        indexes = [
            models.Index(fields=['is_processed', 'scheduled_for']),
            models.Index(fields=['user', 'notification_type']),
        ]
    
    def __str__(self):
        return f"{self.notification_type} for {self.user.username} - {self.scheduled_for}"
    
    def process(self):
        """
        Process this queued notification.
        """
        if self.is_processed:
            return False
        
        if self.attempts >= self.max_attempts:
            self.is_processed = True
            self.error_message = "Max attempts reached"
            self.save()
            return False
        
        try:
            # Check if user preferences allow this notification
            preferences = self.user.notification_preferences
            if not preferences.can_send_notification(self.notification_type):
                self.is_processed = True
                self.processed_at = timezone.now()
                self.save()
                return True
            
            # Check quiet hours
            if preferences.is_quiet_hours():
                # Reschedule for end of quiet hours
                today = timezone.now().date()
                quiet_end = timezone.datetime.combine(today, preferences.quiet_hours_end)
                if quiet_end < timezone.now():
                    # If quiet hours end today has passed, schedule for tomorrow
                    quiet_end += timezone.timedelta(days=1)
                self.scheduled_for = quiet_end
                self.save()
                return False
            
            # Create and send notification
            from notifications.tasks import send_notification
            send_notification.delay(
                self.user.id,
                self.notification_type,
                self.data
            )
            
            self.is_processed = True
            self.processed_at = timezone.now()
            self.save()
            return True
            
        except Exception as e:
            self.attempts += 1
            self.error_message = str(e)
            self.save()
            return False
