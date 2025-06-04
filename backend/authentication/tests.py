"""
Authentication API tests.
"""
from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken
from analytics.models import UserCreditScore
from notifications.models import NotificationPreference

User = get_user_model()


class UserRegistrationTestCase(APITestCase):
    """Test user registration endpoint."""
    
    def setUp(self):
        self.url = reverse('authentication:user_register')
        self.valid_data = {
            'username': 'testuser',
            'email': 'testuser@example.com',
            'password': 'TestPass123!',
            'password_confirm': 'TestPass123!',
            'first_name': 'Test',
            'last_name': 'User',
            'phone_number': '1234567890',
            'user_type': 'student'
        }
    
    def test_successful_registration(self):
        """Test successful user registration."""
        response = self.client.post(self.url, self.valid_data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        
        # Check user was created
        user = User.objects.get(username='testuser')
        self.assertEqual(user.email, 'testuser@example.com')
        self.assertEqual(user.user_type, 'student')
        
        # Check related models were created
        self.assertTrue(hasattr(user, 'creditscores'))
        self.assertTrue(hasattr(user, 'notification_preferences'))
    
    def test_password_mismatch(self):
        """Test registration with mismatched passwords."""
        data = self.valid_data.copy()
        data['password_confirm'] = 'DifferentPass123!'
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password', response.data)
    
    def test_duplicate_email(self):
        """Test registration with existing email."""
        User.objects.create_user(
            username='existing',
            email='testuser@example.com',
            password='ExistingPass123!'
        )
        
        response = self.client.post(self.url, self.valid_data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', response.data)
    
    def test_weak_password(self):
        """Test registration with weak password."""
        data = self.valid_data.copy()
        data['password'] = '123'
        data['password_confirm'] = '123'
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password', response.data)


class LoginTestCase(APITestCase):
    """Test login endpoint."""
    
    def setUp(self):
        self.url = reverse('authentication:token_obtain_pair')
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!',
            first_name='Test',
            last_name='User'
        )
    
    def test_successful_login(self):
        """Test successful login."""
        data = {
            'username': 'testuser',
            'password': 'TestPass123!'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertEqual(response.data['username'], 'testuser')
        self.assertEqual(response.data['email'], 'test@example.com')
    
    def test_invalid_credentials(self):
        """Test login with invalid credentials."""
        data = {
            'username': 'testuser',
            'password': 'WrongPassword123!'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_inactive_user(self):
        """Test login with inactive user."""
        self.user.is_active = False
        self.user.save()
        
        data = {
            'username': 'testuser',
            'password': 'TestPass123!'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class UserProfileTestCase(APITestCase):
    """Test user profile endpoints."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!',
            first_name='Test',
            last_name='User',
            phone_number='1234567890',
            user_type='student'
        )
        self.client.force_authenticate(user=self.user)
        self.url = reverse('authentication:user_profile')
        
        # Create related models
        UserCreditScore.objects.create(user=self.user)
        NotificationPreference.objects.create(user=self.user)
    
    def test_get_profile(self):
        """Test getting user profile."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], 'testuser')
        self.assertEqual(response.data['email'], 'test@example.com')
        self.assertIn('credit_score', response.data)
        self.assertIn('current_borrowed_books', response.data)
        self.assertIn('can_borrow_more', response.data)
    
    def test_update_profile(self):
        """Test updating user profile."""
        data = {
            'first_name': 'Updated',
            'last_name': 'Name',
            'phone_number': '9876543210'
        }
        
        response = self.client.patch(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verify update
        self.user.refresh_from_db()
        self.assertEqual(self.user.first_name, 'Updated')
        self.assertEqual(self.user.last_name, 'Name')
        self.assertEqual(self.user.phone_number, '9876543210')
    
    def test_unauthenticated_access(self):
        """Test accessing profile without authentication."""
        self.client.force_authenticate(user=None)
        
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class ChangePasswordTestCase(APITestCase):
    """Test change password endpoint."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='OldPass123!'
        )
        self.client.force_authenticate(user=self.user)
        self.url = reverse('authentication:change_password')
    
    def test_successful_password_change(self):
        """Test successful password change."""
        data = {
            'old_password': 'OldPass123!',
            'new_password': 'NewPass123!',
            'new_password_confirm': 'NewPass123!'
        }
        
        response = self.client.put(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verify password was changed
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('NewPass123!'))
    
    def test_incorrect_old_password(self):
        """Test password change with incorrect old password."""
        data = {
            'old_password': 'WrongOldPass123!',
            'new_password': 'NewPass123!',
            'new_password_confirm': 'NewPass123!'
        }
        
        response = self.client.put(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('old_password', response.data)
    
    def test_password_mismatch(self):
        """Test password change with mismatched new passwords."""
        data = {
            'old_password': 'OldPass123!',
            'new_password': 'NewPass123!',
            'new_password_confirm': 'DifferentPass123!'
        }
        
        response = self.client.put(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('new_password', response.data)


class TokenRefreshTestCase(APITestCase):
    """Test token refresh endpoint."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!'
        )
        self.refresh_token = RefreshToken.for_user(self.user)
        self.url = reverse('authentication:token_refresh')
    
    def test_successful_token_refresh(self):
        """Test successful token refresh."""
        data = {
            'refresh': str(self.refresh_token)
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
    
    def test_invalid_refresh_token(self):
        """Test refresh with invalid token."""
        data = {
            'refresh': 'invalid-token'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class UserViewSetTestCase(APITestCase):
    """Test user management viewset (admin only)."""
    
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='AdminPass123!'
        )
        self.regular_user = User.objects.create_user(
            username='regular',
            email='regular@example.com',
            password='RegularPass123!'
        )
        
        # Create credit scores
        UserCreditScore.objects.create(user=self.admin)
        UserCreditScore.objects.create(user=self.regular_user)
    
    def test_list_users_as_admin(self):
        """Test listing users as admin."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('authentication:users-list')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 2)
    
    def test_list_users_as_regular_user(self):
        """Test listing users as regular user (should fail)."""
        self.client.force_authenticate(user=self.regular_user)
        url = reverse('authentication:users-list')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_reset_borrowing_limit(self):
        """Test resetting user's borrowing limit."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('authentication:users-reset-borrowing-limit', kwargs={'pk': self.regular_user.id})
        
        response = self.client.post(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verify borrowing limit was reset
        self.regular_user.refresh_from_db()
        self.assertEqual(self.regular_user.max_books_allowed, 5)  # Default for student
