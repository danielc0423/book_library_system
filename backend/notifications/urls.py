"""
Notification URLs for the Library System API.
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    NotificationPreferenceView, NotificationHistoryView,
    NotificationTemplateViewSet, NotificationStatsView,
    ProcessNotificationQueueView
)

app_name = 'notifications'

# Create router for viewsets
router = DefaultRouter()
router.register(r'templates', NotificationTemplateViewSet, basename='notification-templates')

urlpatterns = [
    # User Notification Management
    path('preferences/', NotificationPreferenceView.as_view(), name='notification_preferences'),
    path('history/', NotificationHistoryView.as_view(), name='notification_history'),
    
    # Admin Endpoints
    path('admin/stats/', NotificationStatsView.as_view(), name='notification_stats'),
    path('admin/process-queue/', ProcessNotificationQueueView.as_view(), name='process_notification_queue'),
    
    # Include router URLs
    path('', include(router.urls)),
]
