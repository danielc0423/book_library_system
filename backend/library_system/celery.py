"""
Celery configuration for library_system project.
"""

import os
from celery import Celery

# Set the default Django settings module for the 'celery' program
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'library_system.settings.development')

app = Celery('library_system')

# Using a string here means the worker doesn't have to serialize
# the configuration object to child processes
app.config_from_object('django.conf:settings', namespace='CELERY')

# Load task modules from all registered Django apps
app.autodiscover_tasks()

# Celery beat schedule for periodic tasks
from celery.schedules import crontab

app.conf.beat_schedule = {
    # Daily overdue book reminders at 9:00 AM
    'send-overdue-reminders': {
        'task': 'notifications.tasks.send_overdue_reminders',
        'schedule': crontab(hour=9, minute=0),
        'options': {
            'expires': 3600,  # Task expires after 1 hour if not executed
        }
    },
    # Pre-due reminders at 9:00 AM (3 days before due)
    'send-pre-due-reminders': {
        'task': 'notifications.tasks.send_pre_due_reminders',
        'schedule': crontab(hour=9, minute=0),
        'options': {
            'expires': 3600,
        }
    },
    # Weekly book popularity analytics (Sunday at 2:00 AM)
    'calculate-book-popularity': {
        'task': 'analytics.tasks.calculate_book_popularity',
        'schedule': crontab(hour=2, minute=0, day_of_week=0),
        'options': {
            'expires': 7200,  # Task expires after 2 hours
        }
    },
    # Daily credit score updates (1:00 AM)
    'update-credit-scores': {
        'task': 'analytics.tasks.update_all_credit_scores',
        'schedule': crontab(hour=1, minute=0),
        'options': {
            'expires': 3600,
        }
    },
    # Clean up expired JWT tokens (daily at 3:00 AM)
    'cleanup-blacklisted-tokens': {
        'task': 'authentication.tasks.cleanup_blacklisted_tokens',
        'schedule': crontab(hour=3, minute=0),
        'options': {
            'expires': 3600,
        }
    },
    # Sync with Oracle IDCS (every 6 hours)
    'sync-idcs-users': {
        'task': 'authentication.tasks.sync_idcs_users',
        'schedule': crontab(hour='*/6'),
        'options': {
            'expires': 3600,
        }
    },
}

# Task routing for different queues
app.conf.task_routes = {
    'notifications.tasks.*': {'queue': 'notifications'},
    'analytics.tasks.*': {'queue': 'analytics'},
    'authentication.tasks.*': {'queue': 'auth'},
    'books.tasks.*': {'queue': 'default'},
}

# Task time limits
app.conf.task_time_limit = 300  # 5 minutes
app.conf.task_soft_time_limit = 240  # 4 minutes

# Result expiration
app.conf.result_expires = 3600  # 1 hour


@app.task(bind=True, ignore_result=True)
def debug_task(self):
    """Debug task for testing Celery setup."""
    print(f'Request: {self.request!r}')
