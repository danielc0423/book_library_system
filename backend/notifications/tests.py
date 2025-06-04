"""
Notification API tests.
"""
from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from datetime import time, datetime, timedelta
from .models import NotificationTemplate, NotificationLog, NotificationPreference, NotificationQueue

User = get_user_model()


class NotificationPreferenceTestCase(APITestCase):
    """Test notification preference endpoints."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!'
        )
        self.client.force_authenticate(user=self.user)
        self.url = reverse('notifications:notification_preferences')
    
    def test_get_notification_preferences(self):
        """Test getting notification preferences."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Should create default preferences if not exists
        self.assertTrue(NotificationPreference.objects.filter(user=self.user).exists())
        
        # Check default values
        self.assertTrue(response.data['email_enabled'])
        self.assertTrue(response.data['overdue_reminders'])
        self.assertTrue(response.data['due_date_reminders'])
    
    def test_update_notification_preferences(self):
        """Test updating notification preferences."""
        # Create initial preferences
        NotificationPreference.objects.create(user=self.user)
        
        data = {
            'email_enabled': False,
            'sms_enabled': True,
            'overdue_reminders': False,
            'due_date_reminders': True,
            'reminder_days_before': 5,
            'quiet_hours_start': '22:00:00',
            'quiet_hours_end': '08:00:00'
        }
        
        response = self.client.patch(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verify updates
        pref = NotificationPreference.objects.get(user=self.user)
        self.assertFalse(pref.email_enabled)
        self.assertTrue(pref.sms_enabled)
        self.assertFalse(pref.overdue_reminders)
        self.assertEqual(pref.reminder_days_before, 5)
        self.assertEqual(pref.quiet_hours_start, time(22, 0))
    
    def test_invalid_quiet_hours(self):
        """Test updating with invalid quiet hours."""
        NotificationPreference.objects.create(user=self.user)
        
        data = {
            'quiet_hours_start': '10:00:00',
            'quiet_hours_end': '09:00:00'  # End before start
        }
        
        response = self.client.patch(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('quiet_hours_start', response.data)


class NotificationHistoryTestCase(APITestCase):
    """Test notification history endpoints."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!'
        )
        
        # Create notification template
        self.template = NotificationTemplate.objects.create(
            name='test_template',
            subject='Test Subject',
            body='Test Body',
            template_type='general'
        )
        
        # Create notification logs
        for i in range(15):
            NotificationLog.objects.create(
                user=self.user,
                template=self.template,
                recipient_email=self.user.email,
                subject=f'Subject {i}',
                status='sent' if i % 3 != 0 else 'failed',
                sent_at=timezone.now() - timedelta(days=i)
            )
        
        self.client.force_authenticate(user=self.user)
        self.url = reverse('notifications:notification_history')
    
    def test_get_notification_history(self):
        """Test getting notification history."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        self.assertIn('summary', response.data)
        
        # Check summary stats
        summary = response.data['summary']
        self.assertEqual(summary['total'], 15)
        self.assertEqual(summary['successful'], 10)  # 10 sent
        self.assertEqual(summary['failed'], 5)  # 5 failed
        self.assertEqual(summary['success_rate'], 66.67)
    
    def test_notification_history_pagination(self):
        """Test notification history pagination."""
        response = self.client.get(self.url, {'page_size': 5})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 5)
        self.assertIn('next', response.data)
    
    def test_notification_history_ordering(self):
        """Test notification history is ordered by sent_at desc."""
        response = self.client.get(self.url)
        
        results = response.data['results']
        dates = [r['sent_at'] for r in results]
        
        # Check dates are in descending order
        for i in range(1, len(dates)):
            self.assertGreater(dates[i-1], dates[i])


class NotificationTemplateTestCase(APITestCase):
    """Test notification template endpoints (admin only)."""
    
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='AdminPass123!'
        )
        
        self.regular_user = User.objects.create_user(
            username='regular',
            email='regular@example.com',
            password='RegularPass123!'
        )
        
        # Create templates
        self.template1 = NotificationTemplate.objects.create(
            name='welcome_email',
            subject='Welcome {{user_name}}!',
            body='Welcome to our library, {{user_name}}. Your username is {{username}}.',
            template_type='registration',
            is_active=True
        )
        
        self.template2 = NotificationTemplate.objects.create(
            name='overdue_reminder',
            subject='Overdue Book Reminder',
            body='Your book {{book_title}} is {{days_overdue}} days overdue.',
            template_type='reminder',
            is_active=True
        )
    
    def test_list_templates_as_admin(self):
        """Test listing templates as admin."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('notifications:notification-templates-list')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 2)
    
    def test_list_templates_as_regular_user(self):
        """Test listing templates as regular user (should fail)."""
        self.client.force_authenticate(user=self.regular_user)
        url = reverse('notifications:notification-templates-list')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_create_template(self):
        """Test creating a notification template."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('notifications:notification-templates-list')
        
        data = {
            'name': 'new_template',
            'subject': 'New Template Subject',
            'body': 'New template body with {{variable}}',
            'template_type': 'general',
            'is_active': True
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(NotificationTemplate.objects.count(), 3)
    
    def test_preview_template(self):
        """Test previewing a notification template."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('notifications:notification-templates-preview', 
                     kwargs={'pk': self.template1.id})
        
        response = self.client.post(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('preview', response.data)
        self.assertIn('sample_context', response.data)
        
        # Check variable substitution
        preview = response.data['preview']
        self.assertIn('John Doe', preview['subject'])  # user_name replaced
        self.assertIn('John Doe', preview['body'])
    
    def test_send_test_notification(self):
        """Test sending a test notification."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('notifications:notification-templates-send-test', 
                     kwargs={'pk': self.template1.id})
        
        data = {
            'email': 'test@example.com'
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('message', response.data)


class NotificationStatsTestCase(APITestCase):
    """Test notification statistics endpoint."""
    
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='AdminPass123!'
        )
        
        self.user = User.objects.create_user(
            username='user',
            email='user@example.com',
            password='UserPass123!'
        )
        
        # Create templates
        self.template1 = NotificationTemplate.objects.create(
            name='template1',
            subject='Subject 1',
            body='Body 1',
            template_type='general'
        )
        
        self.template2 = NotificationTemplate.objects.create(
            name='template2',
            subject='Subject 2',
            body='Body 2',
            template_type='reminder'
        )
        
        # Create notification logs
        for i in range(20):
            NotificationLog.objects.create(
                user=self.user,
                template=self.template1 if i % 2 == 0 else self.template2,
                recipient_email=self.user.email,
                subject=f'Subject {i}',
                status='sent' if i % 3 != 0 else 'failed',
                sent_at=timezone.now() - timedelta(days=i)
            )
        
        # Create queue items
        for i in range(5):
            NotificationQueue.objects.create(
                user=self.user,
                notification_type='overdue_reminder',
                context={'book_title': f'Book {i}'},
                status='pending' if i < 3 else 'processing'
            )
        
        self.client.force_authenticate(user=self.admin)
        self.url = reverse('notifications:notification_stats')
    
    def test_get_notification_stats(self):
        """Test getting notification statistics."""
        response = self.client.get(self.url, {'days': '30'})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Check summary
        self.assertEqual(response.data['summary']['total_sent'], 20)
        self.assertGreater(response.data['summary']['successful'], 0)
        self.assertGreater(response.data['summary']['failed'], 0)
        self.assertIn('success_rate', response.data['summary'])
        
        # Check other stats
        self.assertIn('status_breakdown', response.data)
        self.assertIn('template_usage', response.data)
        self.assertIn('daily_trends', response.data)
        self.assertIn('queue_status', response.data)
        
        # Check queue status
        queue_status = response.data['queue_status']
        self.assertEqual(queue_status['pending'], 3)
        self.assertEqual(queue_status['processing'], 2)
    
    def test_notification_stats_as_regular_user(self):
        """Test accessing stats as regular user (should fail)."""
        self.client.force_authenticate(user=self.user)
        
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class ProcessNotificationQueueTestCase(APITestCase):
    """Test process notification queue endpoint."""
    
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='AdminPass123!'
        )
        
        self.user = User.objects.create_user(
            username='user',
            email='user@example.com',
            password='UserPass123!'
        )
        
        # Create pending notifications
        for i in range(3):
            NotificationQueue.objects.create(
                user=self.user,
                notification_type='reminder',
                context={'message': f'Reminder {i}'},
                status='pending'
            )
        
        self.client.force_authenticate(user=self.admin)
        self.url = reverse('notifications:process_notification_queue')
    
    def test_trigger_queue_processing(self):
        """Test triggering notification queue processing."""
        response = self.client.post(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('message', response.data)
        self.assertEqual(response.data['pending_count'], 3)
    
    def test_process_queue_as_regular_user(self):
        """Test processing queue as regular user (should fail)."""
        self.client.force_authenticate(user=self.user)
        
        response = self.client.post(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
