"""
URL Configuration for library_system project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.2/topics/http/urls/
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView
)
from library_system.health import health_check
from authentication.views_ui import signup_view

# API version prefix
API_V1_PREFIX = 'api/v1/'

urlpatterns = [
    # Admin interface
    path('admin/', admin.site.urls),
    
    # API Documentation
    path(API_V1_PREFIX + 'schema/', SpectacularAPIView.as_view(), name='schema'),
    path(API_V1_PREFIX + 'docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path(API_V1_PREFIX + 'redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
    
    # Authentication endpoints
    path(API_V1_PREFIX + 'auth/', include('authentication.urls', namespace='auth')),
    
    # Book management endpoints
    path(API_V1_PREFIX + 'books/', include('books.urls', namespace='books')),
    
    # Analytics endpoints
    path(API_V1_PREFIX + 'analytics/', include('analytics.urls', namespace='analytics')),
    
    # Notification endpoints (admin only)
    path(API_V1_PREFIX + 'notifications/', include('notifications.urls', namespace='notifications')),
    
    # Health check endpoint
    path('health/', health_check, name='health_check'),
    
    # UI Views
    path('signup/', signup_view, name='signup'),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    
    # Add debug toolbar URLs in development
    try:
        import debug_toolbar
        urlpatterns = [
            path('__debug__/', include(debug_toolbar.urls)),
        ] + urlpatterns
    except ImportError:
        pass

# Custom error handlers
handler404 = 'library_system.views.custom_404'
handler500 = 'library_system.views.custom_500'
handler403 = 'library_system.views.custom_403'
handler400 = 'library_system.views.custom_400'
