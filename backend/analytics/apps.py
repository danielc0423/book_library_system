from django.apps import AppConfig


class AnalyticsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'analytics'
    verbose_name = 'Analytics & Reporting'
    
    def ready(self):
        """Import signal handlers when the app is ready."""
        try:
            import analytics.signals  # noqa
        except ImportError:
            pass
