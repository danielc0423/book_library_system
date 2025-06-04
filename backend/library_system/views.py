"""
Custom error views for the library system.
"""
from django.http import JsonResponse
from rest_framework import status


def custom_404(request, exception=None):
    """
    Custom 404 error handler.
    """
    return JsonResponse({
        'error': True,
        'message': 'The requested resource was not found.',
        'status_code': 404
    }, status=status.HTTP_404_NOT_FOUND)


def custom_500(request):
    """
    Custom 500 error handler.
    """
    return JsonResponse({
        'error': True,
        'message': 'An internal server error occurred. Please try again later.',
        'status_code': 500
    }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def custom_403(request, exception=None):
    """
    Custom 403 error handler.
    """
    return JsonResponse({
        'error': True,
        'message': 'You do not have permission to access this resource.',
        'status_code': 403
    }, status=status.HTTP_403_FORBIDDEN)


def custom_400(request, exception=None):
    """
    Custom 400 error handler.
    """
    return JsonResponse({
        'error': True,
        'message': 'Bad request. Please check your input and try again.',
        'status_code': 400
    }, status=status.HTTP_400_BAD_REQUEST)
