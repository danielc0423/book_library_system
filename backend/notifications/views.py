"""
Notification views for the Library System API.
"""
from rest_framework import generics, status, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Count, Q
from django.utils import timezone
from datetime import timedelta
from .models import NotificationTemplate, NotificationLog, NotificationPreference, NotificationQueue
from .serializers import (
    NotificationPreferenceSerializer, NotificationLogSerializer,
    NotificationTemplateSerializer
)
from .tasks import send_notification, process_notification_queue


class NotificationPreferenceView(generics.RetrieveUpdateAPIView):
    """Get and update user notification preferences."""
    serializer_class = NotificationPreferenceSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        # Get or create notification preferences
        preference, created = NotificationPreference.objects.get_or_create(
            user=self.request.user,
            defaults={
                'email_enabled': True,
                'overdue_reminders': True,
                'due_date_reminders': True
            }
        )
        return preference


class NotificationHistoryView(generics.ListAPIView):
    """List user's notification history."""
    serializer_class = NotificationLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return NotificationLog.objects.filter(
            user=self.request.user
        ).select_related('template').order_by('-sent_at')
    
    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())
        
        # Add summary statistics
        total_notifications = queryset.count()
        successful = queryset.filter(status='sent').count()
        failed = queryset.filter(status='failed').count()
        
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            response = self.get_paginated_response(serializer.data)
            response.data['summary'] = {
                'total': total_notifications,
                'successful': successful,
                'failed': failed,
                'success_rate': round((successful / total_notifications * 100) if total_notifications > 0 else 0, 2)
            }
            return response
        
        serializer = self.get_serializer(queryset, many=True)
        return Response({
            'results': serializer.data,
            'summary': {
                'total': total_notifications,
                'successful': successful,
                'failed': failed,
                'success_rate': round((successful / total_notifications * 100) if total_notifications > 0 else 0, 2)
            }
        })


class NotificationTemplateViewSet(viewsets.ModelViewSet):
    """Manage notification templates (admin only)."""
    queryset = NotificationTemplate.objects.all()
    serializer_class = NotificationTemplateSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['template_type', 'is_active']
    search_fields = ['name', 'subject', 'body']
    ordering = ['name']
    
    @action(detail=True, methods=['post'])
    def preview(self, request, pk=None):
        """Preview a notification template with sample data."""
        template = self.get_object()
        
        # Sample context data for preview
        sample_context = {
            'user_name': 'John Doe',
            'book_title': 'Sample Book Title',
            'due_date': (timezone.now().date() + timedelta(days=7)).strftime('%B %d, %Y'),
            'days_overdue': 3,
            'late_fee': 15.00,
            'renewal_count': 1,
            'book_count': 3,
            'book_titles': ['Book 1', 'Book 2', 'Book 3']
        }
        
        # Render template with sample context
        try:
            rendered_subject = template.subject
            rendered_body = template.body
            
            for key, value in sample_context.items():
                placeholder = f'{{{{{key}}}}}'
                rendered_subject = rendered_subject.replace(placeholder, str(value))
                rendered_body = rendered_body.replace(placeholder, str(value))
            
            return Response({
                'template': {
                    'name': template.name,
                    'type': template.template_type
                },
                'preview': {
                    'subject': rendered_subject,
                    'body': rendered_body
                },
                'sample_context': sample_context
            })
        except Exception as e:
            return Response({
                'error': f'Failed to render template: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=True, methods=['post'])
    def send_test(self, request, pk=None):
        """Send a test notification using this template."""
        template = self.get_object()
        recipient_email = request.data.get('email', request.user.email)
        
        # Send test notification
        try:
            send_notification.delay(
                user_id=request.user.id,
                template_name=template.name,
                context={
                    'user_name': request.user.get_full_name(),
                    'test_message': 'This is a test notification.'
                },
                recipient_email_override=recipient_email
            )
            
            return Response({
                'message': f'Test notification sent to {recipient_email}'
            })
        except Exception as e:
            return Response({
                'error': f'Failed to send test notification: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class NotificationStatsView(APIView):
    """Get notification statistics (admin only)."""
    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request):
        days = int(request.query_params.get('days', 30))
        start_date = timezone.now() - timedelta(days=days)
        
        # Get notification counts by status
        status_counts = NotificationLog.objects.filter(
            sent_at__gte=start_date
        ).values('status').annotate(count=Count('id'))
        
        # Get notification counts by template
        template_counts = NotificationLog.objects.filter(
            sent_at__gte=start_date
        ).values('template__name', 'template__template_type').annotate(
            count=Count('id'),
            success_count=Count('id', filter=Q(status='sent')),
            failure_count=Count('id', filter=Q(status='failed'))
        ).order_by('-count')
        
        # Get daily notification trends
        daily_trends = NotificationLog.objects.filter(
            sent_at__gte=start_date
        ).extra(
            select={'day': 'DATE(sent_at)'}
        ).values('day').annotate(
            total=Count('id'),
            sent=Count('id', filter=Q(status='sent')),
            failed=Count('id', filter=Q(status='failed'))
        ).order_by('day')
        
        # Get queue status
        queue_status = {
            'pending': NotificationQueue.objects.filter(
                status='pending'
            ).count(),
            'processing': NotificationQueue.objects.filter(
                status='processing'
            ).count(),
            'scheduled': NotificationQueue.objects.filter(
                status='pending',
                scheduled_for__gt=timezone.now()
            ).count()
        }
        
        # Calculate success rate
        total_notifications = NotificationLog.objects.filter(
            sent_at__gte=start_date
        ).count()
        
        successful_notifications = NotificationLog.objects.filter(
            sent_at__gte=start_date,
            status='sent'
        ).count()
        
        success_rate = (successful_notifications / total_notifications * 100) if total_notifications > 0 else 0
        
        return Response({
            'period': {
                'start_date': start_date.date(),
                'end_date': timezone.now().date(),
                'days': days
            },
            'summary': {
                'total_sent': total_notifications,
                'successful': successful_notifications,
                'failed': total_notifications - successful_notifications,
                'success_rate': round(success_rate, 2)
            },
            'status_breakdown': {item['status']: item['count'] for item in status_counts},
            'template_usage': list(template_counts),
            'daily_trends': list(daily_trends),
            'queue_status': queue_status
        })


class ProcessNotificationQueueView(APIView):
    """Manually trigger notification queue processing (admin only)."""
    permission_classes = [permissions.IsAdminUser]
    
    def post(self, request):
        # Trigger queue processing
        process_notification_queue.delay()
        
        return Response({
            'message': 'Notification queue processing triggered.',
            'pending_count': NotificationQueue.objects.filter(
                status='pending'
            ).count()
        })
