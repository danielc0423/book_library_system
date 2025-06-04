"""
Development settings for library_system project.
"""

from .base import *  # noqa: F403

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

# Allow all hosts in development
ALLOWED_HOSTS = ['*']

# Database configuration for development
# Using SQLite for easy local development, can be changed to Oracle
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',  # noqa: F405
    }
}

# Alternatively, use Oracle database in development:
# Uncomment below and comment out SQLite config above
"""
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.oracle',
        'NAME': config('DEV_DB_NAME', default='XEPDB1'),  # noqa: F405
        'USER': config('DEV_DB_USER', default='library_dev'),  # noqa: F405
        'PASSWORD': config('DEV_DB_PASSWORD', default=''),  # noqa: F405
        'HOST': config('DEV_DB_HOST', default='localhost'),  # noqa: F405
        'PORT': config('DEV_DB_PORT', default='1521'),  # noqa: F405
        'OPTIONS': {
            'threaded': True,
            'use_returning_into': False,
        },
    }
}
"""

# Development-specific installed apps
# Only add django_extensions if it's installed
try:
    import django_extensions  # noqa: F401
    INSTALLED_APPS += ['django_extensions']  # noqa: F405
except ImportError:
    pass

# Email backend for development (console output)
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# Static files configuration for development
STATICFILES_DIRS = [
    BASE_DIR / 'static',  # noqa: F405
]

# Media files configuration for development
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'  # noqa: F405

# CORS configuration for development (allow all origins)
CORS_ALLOW_ALL_ORIGINS = True

# Debug toolbar configuration (optional)
if DEBUG:
    try:
        import debug_toolbar  # noqa: F401
        INSTALLED_APPS += ['debug_toolbar']  # noqa: F405
        MIDDLEWARE.insert(0, 'debug_toolbar.middleware.DebugToolbarMiddleware')  # noqa: F405
        INTERNAL_IPS = ['127.0.0.1', 'localhost']
    except ImportError:
        pass

# Celery configuration for development
CELERY_TASK_ALWAYS_EAGER = True  # Execute tasks synchronously in development
CELERY_TASK_EAGER_PROPAGATES = True

# Disable HTTPS requirements in development
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False

# Development logging - reduce verbosity
LOGGING['handlers']['console']['level'] = 'INFO'  # noqa: F405
LOGGING['loggers']['django']['level'] = 'INFO'  # noqa: F405

# Disable file watcher debug messages
LOGGING['loggers']['django.utils.autoreload'] = {  # noqa: F405
    'handlers': ['console'],
    'level': 'WARNING',
    'propagate': False,
}

# Show all SQL queries in console (optional, can be verbose)
# LOGGING['loggers']['django.db.backends'] = {
#     'handlers': ['console'],
#     'level': 'DEBUG',
#     'propagate': False,
# }

# API Documentation - Enable schema endpoint in development
SPECTACULAR_SETTINGS['SERVE_INCLUDE_SCHEMA'] = True  # noqa: F405

# Development-specific application settings
DEVELOPMENT_FEATURES = {
    'ENABLE_DEBUG_ENDPOINTS': True,
    'MOCK_ORACLE_SERVICES': True,  # Mock Oracle Cloud services in development
    'SKIP_EMAIL_VERIFICATION': True,  # Skip email verification in development
    'AUTO_CREATE_SAMPLE_DATA': True,  # Create sample data on first run
}

# Override cache to use local memory in development
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'unique-snowflake',
    }
}

print("Loading development settings...")
