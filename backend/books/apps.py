from django.apps import AppConfig


class BooksConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'books'
    verbose_name = 'Books Management'
    
    def ready(self):
        """Import signal handlers when the app is ready."""
        try:
            import books.signals  # noqa
        except ImportError:
            pass
