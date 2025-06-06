"""
WSGI config for library_system project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/4.2/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application

# Default to production settings unless specified
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'library_system.settings.production')

application = get_wsgi_application()
