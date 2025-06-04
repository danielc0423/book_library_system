from django.apps import AppConfig


class AuthenticationConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'authentication'
    verbose_name = 'User Authentication'
    
    def ready(self):
        """Import signal handlers when the app is ready."""
        try:
            import authentication.signals  # noqa
        except ImportError:
            pass
