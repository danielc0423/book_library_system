"""
Oracle IDCS Authentication Views
Handles OAuth2 flow for IDCS authentication.
"""
import uuid
import logging
from django.shortcuts import redirect
from django.urls import reverse
from django.contrib.auth import authenticate, login
from django.conf import settings
from django.http import JsonResponse, HttpResponseBadRequest
from django.views import View
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, serializers
from rest_framework_simplejwt.tokens import RefreshToken
from drf_spectacular.utils import extend_schema, extend_schema_view

from .client import AuthenticationManager, IDCSException, get_idcs_config

logger = logging.getLogger(__name__)


class IDCSLoginView(View):
    """
    Initiate IDCS OAuth2 login flow.
    """
    
    def get(self, request):
        """
        Redirect user to IDCS login page.
        """
        # Generate state for CSRF protection
        state = str(uuid.uuid4())
        request.session['idcs_state'] = state
        
        # Store the next URL if provided
        next_url = request.GET.get('next', '/')
        request.session['idcs_next'] = next_url
        
        # Get IDCS configuration
        config = get_idcs_config()
        auth_manager = AuthenticationManager(config)
        
        # Generate authorization URL
        redirect_uri = request.build_absolute_uri(reverse('auth:idcs_callback'))
        auth_url = auth_manager.get_authorization_code_url(
            redirect_uri=redirect_uri,
            scope=config['scope'],
            state=state
        )
        
        return redirect(auth_url)


class IDCSCallbackView(View):
    """
    Handle IDCS OAuth2 callback.
    """
    
    def get(self, request):
        """
        Process IDCS callback with authorization code.
        """
        # Get parameters
        code = request.GET.get('code')
        state = request.GET.get('state')
        error = request.GET.get('error')
        
        # Check for errors
        if error:
            error_description = request.GET.get('error_description', 'Authentication failed')
            logger.error(f"IDCS authentication error: {error} - {error_description}")
            return JsonResponse({
                'error': error,
                'error_description': error_description
            }, status=400)
        
        # Verify state
        session_state = request.session.get('idcs_state')
        if not state or state != session_state:
            logger.error("Invalid state parameter in IDCS callback")
            return HttpResponseBadRequest("Invalid state parameter")
        
        # Exchange code for tokens
        try:
            config = get_idcs_config()
            auth_manager = AuthenticationManager(config)
            
            redirect_uri = request.build_absolute_uri(reverse('auth:idcs_callback'))
            token_response = auth_manager.exchange_authorization_code(code, redirect_uri)
            
            access_token = token_response['access_token']
            id_token = token_response['id_token']
            
            # Authenticate user
            user = authenticate(
                request,
                access_token=access_token,
                id_token=id_token
            )
            
            if user:
                # Log the user in
                login(request, user)
                
                # Clean up session
                del request.session['idcs_state']
                next_url = request.session.pop('idcs_next', '/')
                
                # For API clients, return JWT tokens
                if request.META.get('HTTP_ACCEPT') == 'application/json':
                    refresh = RefreshToken.for_user(user)
                    return JsonResponse({
                        'access': str(refresh.access_token),
                        'refresh': str(refresh),
                        'user_id': user.id,
                        'username': user.username,
                        'email': user.email
                    })
                
                # For web clients, redirect
                return redirect(next_url)
            else:
                logger.error("Authentication failed - no user returned")
                return JsonResponse({
                    'error': 'authentication_failed',
                    'error_description': 'Failed to authenticate user'
                }, status=401)
                
        except IDCSException as e:
            logger.error(f"IDCS token exchange failed: {str(e)}")
            return JsonResponse({
                'error': 'token_exchange_failed',
                'error_description': str(e)
            }, status=400)
        except Exception as e:
            logger.exception(f"Unexpected error in IDCS callback: {str(e)}")
            return JsonResponse({
                'error': 'internal_error',
                'error_description': 'An unexpected error occurred'
            }, status=500)


class IDCSLogoutView(View):
    """
    Handle IDCS logout.
    """
    
    def post(self, request):
        """
        Logout user from both Django and IDCS.
        """
        # Get ID token from session if available
        id_token = request.session.get('idcs_id_token')
        
        # Django logout
        from django.contrib.auth import logout
        logout(request)
        
        # IDCS logout URL
        config = get_idcs_config()
        logout_url = f"{config['BaseUrl']}/oauth2/v1/userlogout"
        
        # Build post logout redirect URI
        post_logout_uri = request.build_absolute_uri('/')
        
        # If we have an ID token, redirect to IDCS logout
        if id_token:
            idcs_logout_url = f"{logout_url}?post_logout_redirect_uri={post_logout_uri}&id_token_hint={id_token}"
            return redirect(idcs_logout_url)
        
        # Otherwise just redirect to home
        return redirect('/')


class IDCSTokenRefreshSerializer(serializers.Serializer):
    """Serializer for IDCS token refresh."""
    refresh_token = serializers.CharField(required=True, help_text="IDCS refresh token")


class IDCSUserInfoSerializer(serializers.Serializer):
    """Serializer for IDCS user info response."""
    # This is just for schema documentation, actual response varies
    pass


@extend_schema_view(
    post=extend_schema(
        request=IDCSTokenRefreshSerializer,
        responses={
            200: {
                'type': 'object',
                'properties': {
                    'access_token': {'type': 'string'},
                    'expires_in': {'type': 'integer'},
                    'token_type': {'type': 'string'}
                }
            }
        },
        description="Refresh IDCS access token using refresh token"
    )
)
class IDCSTokenRefreshView(APIView):
    """Refresh IDCS tokens using refresh token."""
    serializer_class = IDCSTokenRefreshSerializer
    
    def post(self, request):
        """
        Refresh access token using refresh token.
        """
        refresh_token = request.data.get('refresh_token')
        
        if not refresh_token:
            return Response({
                'error': 'missing_refresh_token',
                'error_description': 'Refresh token is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            config = get_idcs_config()
            auth_manager = AuthenticationManager(config)
            
            # Refresh the token
            token_response = auth_manager.refresh_access_token(refresh_token)
            
            return Response({
                'access_token': token_response['access_token'],
                'expires_in': token_response.get('expires_in', 3600),
                'token_type': token_response.get('token_type', 'Bearer')
            })
            
        except IDCSException as e:
            logger.error(f"Token refresh failed: {str(e)}")
            return Response({
                'error': 'token_refresh_failed',
                'error_description': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)


@extend_schema_view(
    get=extend_schema(
        responses={
            200: {
                'type': 'object',
                'description': 'IDCS user information'
            }
        },
        description="Get IDCS user information using access token"
    )
)
class IDCSUserInfoView(APIView):
    """Get IDCS user information using access token."""
    serializer_class = IDCSUserInfoSerializer
    
    def get(self, request):
        """
        Get user info from IDCS.
        """
        # Get access token from Authorization header
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        if not auth_header.startswith('Bearer '):
            return Response({
                'error': 'invalid_authorization',
                'error_description': 'Bearer token required'
            }, status=status.HTTP_401_UNAUTHORIZED)
        
        access_token = auth_header[7:]  # Remove 'Bearer ' prefix
        
        try:
            config = get_idcs_config()
            auth_manager = AuthenticationManager(config)
            
            # Get user info
            user_info = auth_manager.get_user_info(access_token)
            
            return Response(user_info)
            
        except IDCSException as e:
            logger.error(f"Failed to get user info: {str(e)}")
            return Response({
                'error': 'user_info_failed',
                'error_description': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
