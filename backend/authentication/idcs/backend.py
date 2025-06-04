"""
Oracle IDCS Authentication Backend for Django
This backend handles authentication against Oracle Identity Cloud Service.
"""
from django.contrib.auth.backends import BaseBackend
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.conf import settings
from typing import Optional, Dict
import logging

from .client import AuthenticationManager, UserManager, IDCSException, get_idcs_config

logger = logging.getLogger(__name__)
User = get_user_model()


class IDCSAuthenticationBackend(BaseBackend):
    """
    Django authentication backend for Oracle IDCS.
    Handles user authentication and automatic user creation/update.
    """
    
    def authenticate(self, request, access_token: str = None, id_token: str = None, **kwargs) -> Optional[User]:
        """
        Authenticate user using IDCS tokens.
        
        Args:
            request: Django request object
            access_token: IDCS access token
            id_token: IDCS ID token
            **kwargs: Additional parameters
            
        Returns:
            Authenticated user or None
        """
        if not access_token or not id_token:
            return None
        
        try:
            # Initialize IDCS client
            config = get_idcs_config()
            auth_manager = AuthenticationManager(config)
            
            # Verify ID token
            id_token_verified = auth_manager.verify_id_token(id_token)
            
            # Get user information
            idcs_user_id = id_token_verified.get_user_id()
            email = id_token_verified.get_email()
            display_name = id_token_verified.get_display_name()
            groups = id_token_verified.get_groups()
            
            # Get additional user info using access token
            user_info = auth_manager.get_user_info(access_token)
            
            # Extract user details
            username = user_info.get('userName', email.split('@')[0])
            first_name = user_info.get('name', {}).get('givenName', '')
            last_name = user_info.get('name', {}).get('familyName', '')
            
            # Get or create user
            user = self._get_or_create_user(
                idcs_user_id=idcs_user_id,
                username=username,
                email=email,
                first_name=first_name,
                last_name=last_name,
                groups=groups,
                is_email_verified=id_token_verified.is_email_verified()
            )
            
            # Update last login
            user.last_login_date = timezone.now()
            user.save(update_fields=['last_login_date'])
            
            return user
            
        except IDCSException as e:
            logger.error(f"IDCS authentication failed: {str(e)}")
            return None
        except Exception as e:
            logger.exception(f"Unexpected error during IDCS authentication: {str(e)}")
            return None
    
    def _get_or_create_user(self, idcs_user_id: str, username: str, email: str,
                           first_name: str, last_name: str, groups: list,
                           is_email_verified: bool) -> User:
        """
        Get existing user or create new user from IDCS data.
        
        Args:
            idcs_user_id: IDCS user ID
            username: Username
            email: Email address
            first_name: First name
            last_name: Last name
            groups: IDCS group memberships
            is_email_verified: Email verification status
            
        Returns:
            User instance
        """
        # Try to find user by IDCS ID
        try:
            user = User.objects.get(idcs_user_id=idcs_user_id)
            # Update user information
            user.email = email
            user.first_name = first_name
            user.last_name = last_name
            user.idcs_groups = groups
            user.email_verified = is_email_verified
            user.idcs_last_sync = timezone.now()
            user.save()
            return user
        except User.DoesNotExist:
            pass
        
        # Try to find user by email
        try:
            user = User.objects.get(email=email)
            # Link to IDCS
            user.idcs_user_id = idcs_user_id
            user.idcs_groups = groups
            user.email_verified = is_email_verified
            user.idcs_last_sync = timezone.now()
            user.save()
            return user
        except User.DoesNotExist:
            pass
        
        # Create new user
        user = User.objects.create_user(
            username=username,
            email=email,
            first_name=first_name,
            last_name=last_name,
            idcs_user_id=idcs_user_id,
            idcs_groups=groups,
            email_verified=is_email_verified,
            idcs_last_sync=timezone.now(),
            # Set user type based on groups
            user_type=self._determine_user_type(groups)
        )
        
        return user
    
    def _determine_user_type(self, groups: list) -> str:
        """
        Determine user type based on IDCS groups.
        
        Args:
            groups: List of IDCS group names
            
        Returns:
            User type string
        """
        # Map IDCS groups to user types
        group_mapping = {
            'LibraryAdmins': 'admin',
            'LibraryStaff': 'staff',
            'Faculty': 'faculty',
            'Students': 'student'
        }
        
        for group in groups:
            if group in group_mapping:
                return group_mapping[group]
        
        # Default to student
        return 'student'
    
    def get_user(self, user_id: int) -> Optional[User]:
        """
        Get user by ID.
        
        Args:
            user_id: User ID
            
        Returns:
            User instance or None
        """
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None


class IDCSUserSyncMixin:
    """
    Mixin for syncing users with Oracle IDCS.
    """
    
    def sync_user_with_idcs(self, user: User) -> bool:
        """
        Sync Django user with IDCS.
        
        Args:
            user: Django user instance
            
        Returns:
            Success status
        """
        try:
            config = get_idcs_config()
            user_manager = UserManager(config)
            
            if user.idcs_user_id:
                # Update existing IDCS user
                user_data = {
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                }
                idcs_user = user_manager.update_user(user.idcs_user_id, user_data)
            else:
                # Create new IDCS user
                user_data = {
                    'username': user.username,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                }
                idcs_user = user_manager.create_user(user_data)
                
                # Update Django user with IDCS ID
                user.idcs_user_id = idcs_user['id']
                user.idcs_guid = idcs_user.get('ocid')
            
            # Update sync timestamp
            user.idcs_last_sync = timezone.now()
            user.save()
            
            return True
            
        except IDCSException as e:
            logger.error(f"Failed to sync user {user.username} with IDCS: {str(e)}")
            return False
    
    def add_user_to_idcs_group(self, user: User, group_name: str) -> bool:
        """
        Add user to an IDCS group.
        
        Args:
            user: Django user instance
            group_name: IDCS group name
            
        Returns:
            Success status
        """
        if not user.idcs_user_id:
            logger.warning(f"User {user.username} has no IDCS ID")
            return False
        
        try:
            config = get_idcs_config()
            user_manager = UserManager(config)
            
            # Get group ID (this would need to be implemented)
            # For now, we'll assume group IDs are stored in settings
            group_mapping = {
                'LibraryAdmins': getattr(settings, 'IDCS_GROUP_ADMINS', ''),
                'LibraryStaff': getattr(settings, 'IDCS_GROUP_STAFF', ''),
                'Faculty': getattr(settings, 'IDCS_GROUP_FACULTY', ''),
                'Students': getattr(settings, 'IDCS_GROUP_STUDENTS', '')
            }
            
            group_id = group_mapping.get(group_name)
            if not group_id:
                logger.error(f"Unknown IDCS group: {group_name}")
                return False
            
            return user_manager.add_user_to_group(user.idcs_user_id, group_id)
            
        except IDCSException as e:
            logger.error(f"Failed to add user {user.username} to group {group_name}: {str(e)}")
            return False
