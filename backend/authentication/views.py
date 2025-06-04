"""
Authentication views for the Library System API.
"""
from rest_framework import generics, status, permissions, viewsets, serializers
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import update_session_auth_hash
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.conf import settings
from django.db import transaction
from drf_spectacular.utils import extend_schema, extend_schema_view
from .models import CustomUser
from .serializers import (
    CustomTokenObtainPairSerializer, UserRegistrationSerializer,
    UserProfileSerializer, UserProfileUpdateSerializer,
    ChangePasswordSerializer, PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer, UserListSerializer
)
from notifications.tasks import send_notification


class CustomTokenObtainPairView(TokenObtainPairView):
    """Custom JWT token obtain view with additional user data."""
    serializer_class = CustomTokenObtainPairSerializer


class UserRegistrationView(generics.CreateAPIView):
    """User registration endpoint."""
    serializer_class = UserRegistrationSerializer
    permission_classes = [permissions.AllowAny]
    
    @transaction.atomic
    def perform_create(self, serializer):
        user = serializer.save()
        
        # Send welcome email
        send_notification.delay(
            user_id=user.id,
            template_name='welcome_email',
            context={
                'user_name': user.get_full_name(),
                'username': user.username
            }
        )
        
        # Generate tokens for auto-login
        refresh = RefreshToken.for_user(user)
        
        # Add tokens to response
        self.tokens = {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }
    
    def create(self, request, *args, **kwargs):
        response = super().create(request, *args, **kwargs)
        response.data.update(self.tokens)
        return response


class UserProfileView(generics.RetrieveUpdateAPIView):
    """User profile view and update."""
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        return self.request.user
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return UserProfileUpdateSerializer
        return UserProfileSerializer


class ChangePasswordView(generics.UpdateAPIView):
    """Change password endpoint."""
    serializer_class = ChangePasswordSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        return self.request.user
    
    def update(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = serializer.save()
        
        # Update session auth hash to prevent logout
        update_session_auth_hash(request, user)
        
        return Response({
            'message': 'Password changed successfully.'
        }, status=status.HTTP_200_OK)


class PasswordResetRequestView(generics.GenericAPIView):
    """Password reset request endpoint."""
    serializer_class = PasswordResetRequestSerializer
    permission_classes = [permissions.AllowAny]
    
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        email = serializer.validated_data['email']
        
        try:
            user = CustomUser.objects.get(email=email)
            
            # Generate password reset token
            token = default_token_generator.make_token(user)
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            
            # Send password reset email
            send_notification.delay(
                user_id=user.id,
                template_name='password_reset',
                context={
                    'user_name': user.get_full_name(),
                    'reset_link': f"{settings.FRONTEND_URL}/reset-password/{uid}/{token}/"
                }
            )
        except CustomUser.DoesNotExist:
            # Don't reveal whether a user exists
            pass
        
        return Response({
            'message': 'If an account exists with this email, you will receive password reset instructions.'
        }, status=status.HTTP_200_OK)


class PasswordResetConfirmView(generics.GenericAPIView):
    """Password reset confirmation endpoint."""
    serializer_class = PasswordResetConfirmSerializer
    permission_classes = [permissions.AllowAny]
    
    def post(self, request, uidb64, token, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        try:
            uid = force_str(urlsafe_base64_decode(uidb64))
            user = CustomUser.objects.get(pk=uid)
        except (TypeError, ValueError, OverflowError, CustomUser.DoesNotExist):
            return Response({
                'error': 'Invalid reset link.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if not default_token_generator.check_token(user, token):
            return Response({
                'error': 'Invalid or expired reset link.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Set new password
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        
        return Response({
            'message': 'Password reset successfully.'
        }, status=status.HTTP_200_OK)


class LogoutSerializer(serializers.Serializer):
    """Serializer for logout endpoint."""
    refresh_token = serializers.CharField(required=False, help_text="JWT refresh token to blacklist")


@extend_schema_view(
    post=extend_schema(
        request=LogoutSerializer,
        responses={
            200: {
                'type': 'object',
                'properties': {
                    'message': {'type': 'string', 'example': 'Logged out successfully.'}
                }
            }
        },
        description="Logout user and blacklist JWT refresh token"
    )
)
class LogoutView(APIView):
    """Logout endpoint (blacklist refresh token)."""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = LogoutSerializer
    
    def post(self, request):
        try:
            refresh_token = request.data.get('refresh_token')
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            
            return Response({
                'message': 'Logged out successfully.'
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'error': 'Invalid token.'
            }, status=status.HTTP_400_BAD_REQUEST)


class UserViewSet(viewsets.ReadOnlyModelViewSet):
    """User management viewset (admin only)."""
    queryset = CustomUser.objects.all()
    serializer_class = UserListSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['user_type', 'is_active', 'email_verified']
    search_fields = ['username', 'email', 'first_name', 'last_name']
    ordering_fields = ['registration_date', 'last_login_date', 'username']
    ordering = ['-registration_date']
    
    @action(detail=True, methods=['post'])
    def sync_idcs(self, request, pk=None):
        """Sync user with Oracle IDCS."""
        user = self.get_object()
        
        try:
            # Trigger IDCS sync
            user.sync_with_idcs()
            
            return Response({
                'message': f'User {user.username} synced with IDCS successfully.'
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'error': f'Failed to sync with IDCS: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=True, methods=['post'])
    def reset_borrowing_limit(self, request, pk=None):
        """Reset user's borrowing limit to default."""
        user = self.get_object()
        
        # Reset based on user type
        if user.user_type == 'student':
            user.max_books_allowed = 5
        elif user.user_type == 'faculty':
            user.max_books_allowed = 10
        elif user.user_type == 'staff':
            user.max_books_allowed = 8
        else:
            user.max_books_allowed = 5
        
        user.save()
        
        return Response({
            'message': f'Borrowing limit reset to {user.max_books_allowed} books.'
        }, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['post'])
    def bulk_verify_email(self, request):
        """Bulk verify user emails."""
        user_ids = request.data.get('user_ids', [])
        
        if not user_ids:
            return Response({
                'error': 'No user IDs provided.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        updated = CustomUser.objects.filter(
            id__in=user_ids
        ).update(email_verified=True)
        
        return Response({
            'message': f'{updated} users email verified.'
        }, status=status.HTTP_200_OK)
