"""
Authentication URLs for the Library System API.
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    CustomTokenObtainPairView, UserRegistrationView,
    UserProfileView, ChangePasswordView,
    PasswordResetRequestView, PasswordResetConfirmView,
    LogoutView, UserViewSet
)
from .idcs.views import (
    IDCSLoginView, IDCSCallbackView, IDCSLogoutView,
    IDCSTokenRefreshView, IDCSUserInfoView
)
from .views_ui import signup_view

app_name = 'authentication'

# Create router for viewsets
router = DefaultRouter()
router.register(r'users', UserViewSet, basename='users')

urlpatterns = [
    # JWT Authentication
    path('login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('logout/', LogoutView.as_view(), name='logout'),
    
    # Oracle IDCS Authentication
    path('idcs/login/', IDCSLoginView.as_view(), name='idcs_login'),
    path('idcs/callback/', IDCSCallbackView.as_view(), name='idcs_callback'),
    path('idcs/logout/', IDCSLogoutView.as_view(), name='idcs_logout'),
    path('idcs/refresh/', IDCSTokenRefreshView.as_view(), name='idcs_refresh'),
    path('idcs/userinfo/', IDCSUserInfoView.as_view(), name='idcs_userinfo'),
    
    # User Registration and Profile
    path('register/', UserRegistrationView.as_view(), name='user_register'),
    path('profile/', UserProfileView.as_view(), name='user_profile'),
    
    # Password Management
    path('change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('reset-password/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('reset-password/<str:uidb64>/<str:token>/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    
    # Include router URLs
    path('', include(router.urls)),
    
    # UI Views (HTML forms)
    path('signup/', signup_view, name='signup_ui'),
]
