"""
Simple health check view for the library system.
"""
from django.http import JsonResponse
from django.views import View
from django.db import connection
from django.utils import timezone


class HealthCheckView(View):
    """
    Simple health check endpoint.
    """
    def get(self, request):
        """
        Check system health.
        """
        health_status = {
            'status': 'healthy',
            'timestamp': timezone.now().isoformat(),
            'checks': {}
        }
        
        # Check database connection
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                if result[0] == 1:
                    health_status['checks']['database'] = {
                        'status': 'up',
                        'message': 'Database connection successful'
                    }
        except Exception as e:
            health_status['status'] = 'unhealthy'
            health_status['checks']['database'] = {
                'status': 'down',
                'message': str(e)
            }
        
        # Check Django
        health_status['checks']['django'] = {
            'status': 'up',
            'message': 'Django application running'
        }
        
        # Overall status
        status_code = 200 if health_status['status'] == 'healthy' else 503
        
        return JsonResponse(health_status, status=status_code)


def health_check(request):
    """
    Function-based health check view.
    """
    view = HealthCheckView()
    return view.get(request)
