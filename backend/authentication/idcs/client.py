"""
Oracle Identity Cloud Service (IDCS) Client Module
This module provides authentication and user management integration with Oracle IDCS.
"""
import requests
import json
import jwt
import time
from datetime import datetime, timedelta
from django.conf import settings
from django.core.cache import cache
from typing import Dict, Optional, List


class IDCSException(Exception):
    """Base exception for IDCS operations."""
    pass


class AuthenticationManager:
    """
    Manages authentication flows with Oracle IDCS.
    """
    
    def __init__(self, config: Dict[str, str]):
        """
        Initialize the Authentication Manager with IDCS configuration.
        
        Args:
            config: Dictionary containing IDCS configuration parameters
        """
        self.client_id = config.get('ClientId')
        self.client_secret = config.get('ClientSecret')
        self.base_url = config.get('BaseUrl')
        self.audience_service_url = config.get('AudienceServiceUrl')
        self.scope = config.get('scope', 'urn:opc:idm:t.user.me openid')
        self.token_issuer = config.get('TokenIssuer', 'https://identity.oraclecloud.com/')
        self.redirect_url = config.get('redirectURL')
        
        # Token endpoints
        self.authorize_url = f"{self.base_url}/oauth2/v1/authorize"
        self.token_url = f"{self.base_url}/oauth2/v1/token"
        self.userinfo_url = f"{self.base_url}/oauth2/v1/userinfo"
        self.introspect_url = f"{self.base_url}/oauth2/v1/introspect"
        
    def get_authorization_code_url(self, redirect_uri: str, scope: str, state: str, 
                                  response_type: str = "code") -> str:
        """
        Generate the authorization URL for IDCS OAuth2 flow.
        
        Args:
            redirect_uri: The callback URL
            scope: OAuth2 scopes
            state: State parameter for CSRF protection
            response_type: OAuth2 response type (default: "code")
            
        Returns:
            Complete authorization URL
        """
        params = {
            'response_type': response_type,
            'client_id': self.client_id,
            'redirect_uri': redirect_uri,
            'scope': scope,
            'state': state,
            'nonce': str(int(time.time()))
        }
        
        query_string = '&'.join([f"{k}={v}" for k, v in params.items()])
        return f"{self.authorize_url}?{query_string}"
    
    def exchange_authorization_code(self, code: str, redirect_uri: str) -> Dict:
        """
        Exchange authorization code for access token.
        
        Args:
            code: Authorization code from IDCS
            redirect_uri: The redirect URI used in authorization request
            
        Returns:
            Token response containing access_token, id_token, etc.
        """
        data = {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': redirect_uri
        }
        
        response = requests.post(
            self.token_url,
            auth=(self.client_id, self.client_secret),
            data=data,
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )
        
        if response.status_code != 200:
            raise IDCSException(f"Token exchange failed: {response.text}")
        
        return response.json()
    
    def verify_id_token(self, id_token: str) -> 'IDTokenVerified':
        """
        Verify and decode IDCS ID token.
        
        Args:
            id_token: JWT ID token from IDCS
            
        Returns:
            Verified token object with user information
        """
        # In production, you should verify the token signature using IDCS public keys
        # For now, we'll decode without verification (NOT FOR PRODUCTION)
        try:
            # Decode token without verification (DEVELOPMENT ONLY)
            decoded = jwt.decode(id_token, options={"verify_signature": False})
            return IDTokenVerified(decoded)
        except jwt.InvalidTokenError as e:
            raise IDCSException(f"Invalid ID token: {str(e)}")
    
    def get_user_info(self, access_token: str) -> Dict:
        """
        Get user information from IDCS using access token.
        
        Args:
            access_token: Valid IDCS access token
            
        Returns:
            User information dictionary
        """
        headers = {
            'Authorization': f'Bearer {access_token}',
            'Accept': 'application/json'
        }
        
        response = requests.get(self.userinfo_url, headers=headers)
        
        if response.status_code != 200:
            raise IDCSException(f"Failed to get user info: {response.text}")
        
        return response.json()
    
    def introspect_token(self, token: str) -> Dict:
        """
        Introspect a token to check its validity and get metadata.
        
        Args:
            token: Access or refresh token
            
        Returns:
            Token introspection response
        """
        data = {
            'token': token,
            'token_type_hint': 'access_token'
        }
        
        response = requests.post(
            self.introspect_url,
            auth=(self.client_id, self.client_secret),
            data=data
        )
        
        if response.status_code != 200:
            raise IDCSException(f"Token introspection failed: {response.text}")
        
        return response.json()
    
    def refresh_access_token(self, refresh_token: str) -> Dict:
        """
        Refresh an access token using a refresh token.
        
        Args:
            refresh_token: Valid refresh token
            
        Returns:
            New token response
        """
        data = {
            'grant_type': 'refresh_token',
            'refresh_token': refresh_token
        }
        
        response = requests.post(
            self.token_url,
            auth=(self.client_id, self.client_secret),
            data=data
        )
        
        if response.status_code != 200:
            raise IDCSException(f"Token refresh failed: {response.text}")
        
        return response.json()


class IDTokenVerified:
    """
    Represents a verified IDCS ID token with user information.
    """
    
    def __init__(self, token_data: Dict):
        self.token_data = token_data
        
    def get_user_id(self) -> str:
        """Get the IDCS user ID."""
        return self.token_data.get('sub', '')
    
    def get_display_name(self) -> str:
        """Get the user's display name."""
        return self.token_data.get('user_displayname', '')
    
    def get_email(self) -> str:
        """Get the user's email address."""
        return self.token_data.get('user_email', '')
    
    def get_groups(self) -> List[str]:
        """Get the user's group memberships."""
        return self.token_data.get('groups', [])
    
    def get_app_roles(self) -> List[str]:
        """Get the user's application roles."""
        return self.token_data.get('app_roles', [])
    
    def get_tenant(self) -> str:
        """Get the user's tenant."""
        return self.token_data.get('user_tenantname', '')
    
    def get_id_token(self) -> Dict:
        """Get the complete ID token data."""
        return self.token_data
    
    def is_email_verified(self) -> bool:
        """Check if the user's email is verified."""
        return self.token_data.get('user_email_verified', False)


class UserManager:
    """
    Manages user operations with Oracle IDCS.
    """
    
    def __init__(self, config: Dict[str, str]):
        """
        Initialize the User Manager with IDCS configuration.
        
        Args:
            config: Dictionary containing IDCS configuration parameters
        """
        self.base_url = config.get('BaseUrl')
        self.client_id = config.get('ClientId')
        self.client_secret = config.get('ClientSecret')
        
        # API endpoints
        self.users_url = f"{self.base_url}/admin/v1/Users"
        self.groups_url = f"{self.base_url}/admin/v1/Groups"
        
        # Get access token for API calls
        self._access_token = None
        self._token_expiry = None
    
    def _get_access_token(self) -> str:
        """
        Get a valid access token for IDCS API calls.
        Uses client credentials grant.
        """
        if self._access_token and self._token_expiry and datetime.now() < self._token_expiry:
            return self._access_token
        
        # Check cache first
        cached_token = cache.get('idcs_admin_token')
        if cached_token:
            return cached_token
        
        # Get new token
        token_url = f"{self.base_url}/oauth2/v1/token"
        data = {
            'grant_type': 'client_credentials',
            'scope': 'urn:opc:idm:__myscopes__'
        }
        
        response = requests.post(
            token_url,
            auth=(self.client_id, self.client_secret),
            data=data
        )
        
        if response.status_code != 200:
            raise IDCSException(f"Failed to get admin access token: {response.text}")
        
        token_data = response.json()
        self._access_token = token_data['access_token']
        expires_in = token_data.get('expires_in', 3600)
        self._token_expiry = datetime.now() + timedelta(seconds=expires_in - 60)
        
        # Cache the token
        cache.set('idcs_admin_token', self._access_token, expires_in - 60)
        
        return self._access_token
    
    def get_user(self, user_id: str) -> Dict:
        """
        Get user details from IDCS.
        
        Args:
            user_id: IDCS user ID
            
        Returns:
            User information dictionary
        """
        headers = {
            'Authorization': f'Bearer {self._get_access_token()}',
            'Accept': 'application/json'
        }
        
        response = requests.get(f"{self.users_url}/{user_id}", headers=headers)
        
        if response.status_code != 200:
            raise IDCSException(f"Failed to get user: {response.text}")
        
        return response.json()
    
    def create_user(self, user_data: Dict) -> Dict:
        """
        Create a new user in IDCS.
        
        Args:
            user_data: User information dictionary
            
        Returns:
            Created user information
        """
        headers = {
            'Authorization': f'Bearer {self._get_access_token()}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        # IDCS user schema
        idcs_user = {
            'schemas': ['urn:ietf:params:scim:schemas:core:2.0:User'],
            'userName': user_data['username'],
            'emails': [
                {
                    'value': user_data['email'],
                    'type': 'work',
                    'primary': True
                }
            ],
            'name': {
                'givenName': user_data.get('first_name', ''),
                'familyName': user_data.get('last_name', ''),
                'formatted': f"{user_data.get('first_name', '')} {user_data.get('last_name', '')}"
            },
            'displayName': f"{user_data.get('first_name', '')} {user_data.get('last_name', '')}",
            'active': True
        }
        
        response = requests.post(
            self.users_url,
            headers=headers,
            json=idcs_user
        )
        
        if response.status_code not in [200, 201]:
            raise IDCSException(f"Failed to create user: {response.text}")
        
        return response.json()
    
    def update_user(self, user_id: str, user_data: Dict) -> Dict:
        """
        Update user information in IDCS.
        
        Args:
            user_id: IDCS user ID
            user_data: Updated user information
            
        Returns:
            Updated user information
        """
        headers = {
            'Authorization': f'Bearer {self._get_access_token()}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        # Get current user data first
        current_user = self.get_user(user_id)
        
        # Update fields
        if 'email' in user_data:
            current_user['emails'][0]['value'] = user_data['email']
        
        if 'first_name' in user_data or 'last_name' in user_data:
            current_user['name']['givenName'] = user_data.get('first_name', current_user['name'].get('givenName', ''))
            current_user['name']['familyName'] = user_data.get('last_name', current_user['name'].get('familyName', ''))
            current_user['name']['formatted'] = f"{current_user['name']['givenName']} {current_user['name']['familyName']}"
            current_user['displayName'] = current_user['name']['formatted']
        
        response = requests.put(
            f"{self.users_url}/{user_id}",
            headers=headers,
            json=current_user
        )
        
        if response.status_code != 200:
            raise IDCSException(f"Failed to update user: {response.text}")
        
        return response.json()
    
    def add_user_to_group(self, user_id: str, group_id: str) -> bool:
        """
        Add user to an IDCS group.
        
        Args:
            user_id: IDCS user ID
            group_id: IDCS group ID
            
        Returns:
            Success status
        """
        headers = {
            'Authorization': f'Bearer {self._get_access_token()}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        # PATCH operation to add member
        patch_data = {
            'schemas': ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
            'Operations': [
                {
                    'op': 'add',
                    'path': 'members',
                    'value': [
                        {
                            'value': user_id,
                            'type': 'User'
                        }
                    ]
                }
            ]
        }
        
        response = requests.patch(
            f"{self.groups_url}/{group_id}",
            headers=headers,
            json=patch_data
        )
        
        return response.status_code == 200


def get_idcs_config() -> Dict[str, str]:
    """
    Get IDCS configuration from Django settings.
    
    Returns:
        IDCS configuration dictionary
    """
    return {
        'ClientId': getattr(settings, 'IDCS_CLIENT_ID', ''),
        'ClientSecret': getattr(settings, 'IDCS_CLIENT_SECRET', ''),
        'BaseUrl': getattr(settings, 'IDCS_BASE_URL', ''),
        'AudienceServiceUrl': getattr(settings, 'IDCS_AUDIENCE_SERVICE_URL', ''),
        'scope': getattr(settings, 'IDCS_SCOPE', 'urn:opc:idm:t.user.me openid'),
        'TokenIssuer': getattr(settings, 'IDCS_TOKEN_ISSUER', 'https://identity.oraclecloud.com/'),
        'redirectURL': getattr(settings, 'IDCS_REDIRECT_URL', '')
    }
