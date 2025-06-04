"""
Production settings for library_system project.
"""

from .base import *  # noqa: F403
import os

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = False

# Must be set in production
ALLOWED_HOSTS = config('ALLOWED_HOSTS', cast=Csv())  # noqa: F405

# Database configuration for production (Oracle Autonomous Database)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.oracle',
        'NAME': config('PROD_DB_NAME'),  # noqa: F405
        'USER': config('PROD_DB_USER'),  # noqa: F405
        'PASSWORD': config('PROD_DB_PASSWORD'),  # noqa: F405
        'HOST': config('PROD_DB_HOST'),  # noqa: F405
        'PORT': config('PROD_DB_PORT', default='1521'),  # noqa: F405
        'OPTIONS': {
            'threaded': True,
            'use_returning_into': False,
            'sessionpool': {
                'min': 2,
                'max': 10,
                'increment': 2,
                'threaded': True,
                'getmode': 'SPOOL_ATTRVAL_WAIT',
                'homogeneous': True,
            },
        },
    }
}

# Security settings for production
SECURE_SSL_REDIRECT = config('SECURE_SSL_REDIRECT', default=True, cast=bool)  # noqa: F405
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SECURE_HSTS_SECONDS = 31536000  # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# Static files configuration for production
STATIC_URL = '/static/'
STATIC_ROOT = config('STATIC_ROOT', default='/var/www/library_system/static/')  # noqa: F405

# Media files configuration for production
MEDIA_URL = '/media/'
MEDIA_ROOT = config('MEDIA_ROOT', default='/var/www/library_system/media/')  # noqa: F405

# Use whitenoise for static file serving
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Email configuration for production
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = config('EMAIL_HOST')  # noqa: F405
EMAIL_PORT = config('EMAIL_PORT', cast=int)  # noqa: F405
EMAIL_USE_TLS = config('EMAIL_USE_TLS', cast=bool)  # noqa: F405
EMAIL_HOST_USER = config('EMAIL_HOST_USER')  # noqa: F405
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD')  # noqa: F405

# Production logging configuration
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/var/log/library_system/django.log',
            'maxBytes': 1024 * 1024 * 100,  # 100MB
            'backupCount': 10,
            'formatter': 'verbose',
        },
        'error_file': {
            'level': 'ERROR',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/var/log/library_system/django_errors.log',
            'maxBytes': 1024 * 1024 * 100,  # 100MB
            'backupCount': 10,
            'formatter': 'verbose',
        },
        'mail_admins': {
            'level': 'ERROR',
            'class': 'django.utils.log.AdminEmailHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file', 'error_file', 'mail_admins'],
            'level': 'INFO',
            'propagate': True,
        },
        'apps': {
            'handlers': ['file', 'error_file'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}

# Admins to receive error emails
ADMINS = [
    ('Admin', config('ADMIN_EMAIL')),  # noqa: F405
]

# Redis cache configuration for production
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': config('REDIS_URL'),  # noqa: F405
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'CONNECTION_POOL_KWARGS': {
                'max_connections': 50,
            },
            'COMPRESSOR': 'django_redis.compressors.zlib.ZlibCompressor',
        },
        'KEY_PREFIX': 'library_prod',
        'TIMEOUT': 300,
    }
}

# Session configuration
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_CACHE_ALIAS = 'default'

# CORS configuration for production
CORS_ALLOWED_ORIGINS = config('CORS_ALLOWED_ORIGINS', cast=Csv())  # noqa: F405
CORS_ALLOW_CREDENTIALS = True

# Oracle Cloud specific configurations
OCI_CONFIG_FILE = config('OCI_CONFIG_FILE')  # noqa: F405
OCI_CONFIG_PROFILE = config('OCI_CONFIG_PROFILE', default='DEFAULT')  # noqa: F405
OCI_COMPARTMENT_ID = config('OCI_COMPARTMENT_ID')  # noqa: F405

# Oracle Integration Cloud configuration
OIC_BASE_URL = config('OIC_BASE_URL')  # noqa: F405
OIC_USERNAME = config('OIC_USERNAME')  # noqa: F405
OIC_PASSWORD = config('OIC_PASSWORD')  # noqa: F405

# Oracle Analytics Cloud configuration
OAC_BASE_URL = config('OAC_BASE_URL')  # noqa: F405
OAC_API_KEY = config('OAC_API_KEY')  # noqa: F405

# Performance optimizations
CONN_MAX_AGE = 600  # Database connection persistence

# Production-specific application settings
PRODUCTION_FEATURES = {
    'ENABLE_PERFORMANCE_MONITORING': True,
    'ENABLE_ERROR_TRACKING': True,
    'ENABLE_AUDIT_LOGGING': True,
    'BACKUP_RETENTION_DAYS': 30,
}

# API rate limiting for production
REST_FRAMEWORK['DEFAULT_THROTTLE_CLASSES'] = [  # noqa: F405
    'rest_framework.throttling.AnonRateThrottle',
    'rest_framework.throttling.UserRateThrottle',
]

REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'] = {  # noqa: F405
    'anon': '100/hour',
    'user': '1000/hour',
}

# Sentry error tracking (optional)
SENTRY_DSN = config('SENTRY_DSN', default='')  # noqa: F405
if SENTRY_DSN:
    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration
    
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[DjangoIntegration()],
        traces_sample_rate=0.1,
        send_default_pii=False,
        environment='production',
    )

print("Loading production settings...")
