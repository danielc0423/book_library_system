"""
Custom permissions for the Library System API.
"""
from rest_framework import permissions


class IsOwnerOrAdmin(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object or admins to access it.
    """
    def has_object_permission(self, request, view, obj):
        # Admin users have full access
        if request.user and request.user.is_staff:
            return True
        
        # Check if the object has a user field
        if hasattr(obj, 'user'):
            return obj.user == request.user
        
        # Check if the object itself is a user
        return obj == request.user


class IsAdminOrReadOnly(permissions.BasePermission):
    """
    Custom permission to only allow admins to edit objects.
    Read permissions are allowed to any authenticated user.
    """
    def has_permission(self, request, view):
        # Read permissions are allowed to authenticated users
        if request.method in permissions.SAFE_METHODS:
            return request.user and request.user.is_authenticated
        
        # Write permissions are only allowed to admin users
        return request.user and request.user.is_staff


class IsSuperuserOrReadOnly(permissions.BasePermission):
    """
    Custom permission to only allow superusers to edit objects.
    Read permissions are allowed to any authenticated user.
    """
    def has_permission(self, request, view):
        # Read permissions are allowed to authenticated users
        if request.method in permissions.SAFE_METHODS:
            return request.user and request.user.is_authenticated
        
        # Write permissions are only allowed to superusers
        return request.user and request.user.is_superuser


class IsOwner(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object to access it.
    """
    def has_object_permission(self, request, view, obj):
        # Check if the object has a user field
        if hasattr(obj, 'user'):
            return obj.user == request.user
        
        # Check if the object itself is a user
        return obj == request.user
