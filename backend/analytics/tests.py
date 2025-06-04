"""
Analytics API tests.
"""
from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from datetime import timedelta
from decimal import Decimal
from .models import UserCreditScore, UserActivityLog, SystemAnalytics
from books.models import Book, BookCategory, BorrowingRecord, BookStatistics

User = get_user_model()


class UserCreditScoreTestCase(APITestCase):
    """Test user credit score endpoint."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!'
        )
        self.credit_score = UserCreditScore.objects.create(
            user=self.user,
            credit_score=750,
            on_time_returns=10,
            late_returns=2,
            total_items_borrowed=12,
            average_return_delay=Decimal('0.5'),
            reliability_rating='Good'
        )
        self.client.force_authenticate(user=self.user)
    
    def test_get_credit_score(self):
        """Test getting user's credit score."""
        url = reverse('analytics:user_credit_score')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(float(response.data['credit_score']), 750.0)
        self.assertEqual(response.data['on_time_returns'], 10)
        self.assertEqual(response.data['late_returns'], 2)
        self.assertIn('score_category', response.data)
        self.assertIn('borrowing_privileges', response.data)
        self.assertIn('score_breakdown', response.data)
    
    def test_credit_score_created_if_missing(self):
        """Test credit score is created if missing."""
        new_user = User.objects.create_user(
            username='newuser',
            email='new@example.com',
            password='NewPass123!'
        )
        self.client.force_authenticate(user=new_user)
        
        url = reverse('analytics:user_credit_score')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(UserCreditScore.objects.filter(user=new_user).exists())


class UserDashboardTestCase(APITestCase):
    """Test user dashboard endpoint."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!',
            first_name='Test',
            last_name='User',
            user_type='student'
        )
        self.credit_score = UserCreditScore.objects.create(
            user=self.user,
            credit_score=800
        )
        
        # Create categories and books
        self.category = BookCategory.objects.create(name='Programming')
        
        self.book1 = Book.objects.create(
            isbn='9781234567890',
            title='Python Programming',
            author='John Doe',
            category=self.category,
            total_copies=5,
            available_copies=5
        )
        
        self.book2 = Book.objects.create(
            isbn='9780987654321',
            title='Django Development',
            author='Jane Smith',
            category=self.category,
            total_copies=3,
            available_copies=3
        )
        
        # Create borrowing records
        self.current_borrow = BorrowingRecord.objects.create(
            user=self.user,
            book=self.book1,
            status='borrowed',
            due_date=timezone.now().date() + timedelta(days=7)
        )
        
        self.past_borrow = BorrowingRecord.objects.create(
            user=self.user,
            book=self.book2,
            status='returned',
            borrow_date=timezone.now().date() - timedelta(days=14),
            return_date=timezone.now().date() - timedelta(days=7),
            late_fees=0
        )
        
        self.client.force_authenticate(user=self.user)
    
    def test_get_user_dashboard(self):
        """Test getting user dashboard data."""
        url = reverse('analytics:user_dashboard')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Check user summary
        self.assertEqual(response.data['user_summary']['name'], 'Test User')
        self.assertEqual(response.data['user_summary']['user_type'], 'student')
        self.assertEqual(float(response.data['user_summary']['credit_score']), 800.0)
        
        # Check borrowing summary
        self.assertEqual(response.data['borrowing_summary']['current_borrowed'], 1)
        self.assertEqual(response.data['borrowing_summary']['total_borrowed'], 2)
        self.assertTrue(response.data['borrowing_summary']['can_borrow_more'])
        
        # Check current books
        self.assertEqual(len(response.data['current_books']), 1)
        self.assertEqual(response.data['current_books'][0]['title'], 'Python Programming')
        
        # Check history
        self.assertEqual(len(response.data['borrowing_history']), 1)
        self.assertEqual(response.data['borrowing_history'][0]['book_title'], 'Django Development')


class BookStatisticsTestCase(APITestCase):
    """Test book statistics endpoint."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!'
        )
        
        # Create categories and books
        self.category1 = BookCategory.objects.create(name='Programming')
        self.category2 = BookCategory.objects.create(name='Science')
        
        self.book1 = Book.objects.create(
            isbn='9781234567890',
            title='Python Programming',
            author='John Doe',
            category=self.category1,
            total_copies=5,
            available_copies=3
        )
        
        self.book2 = Book.objects.create(
            isbn='9780987654321',
            title='Data Science',
            author='Jane Smith',
            category=self.category2,
            total_copies=3,
            available_copies=1
        )
        
        # Create statistics
        self.stats1 = BookStatistics.objects.create(
            book=self.book1,
            total_borrowed_count=50,
            current_borrowed_count=2,
            average_borrowing_duration=14.5,
            popularity_score=85.0,
            last_borrowed_date=timezone.now().date()
        )
        
        self.stats2 = BookStatistics.objects.create(
            book=self.book2,
            total_borrowed_count=30,
            current_borrowed_count=2,
            average_borrowing_duration=21.0,
            popularity_score=65.0,
            last_borrowed_date=timezone.now().date() - timedelta(days=5)
        )
        
        self.client.force_authenticate(user=self.user)
    
    def test_get_book_statistics(self):
        """Test getting book statistics."""
        url = reverse('analytics:book_statistics')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 2)
        
        # Check first book stats
        first_stat = response.data['results'][0]
        self.assertEqual(first_stat['book_title'], 'Python Programming')
        self.assertEqual(first_stat['total_borrowed_count'], 50)
        self.assertIn('availability_rate', first_stat)
    
    def test_filter_statistics_by_category(self):
        """Test filtering statistics by category."""
        url = reverse('analytics:book_statistics')
        
        response = self.client.get(url, {'category': str(self.category1.id)})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['results'][0]['book_title'], 'Python Programming')
    
    def test_filter_statistics_by_days(self):
        """Test filtering statistics by days."""
        url = reverse('analytics:book_statistics')
        
        response = self.client.get(url, {'days': '3'})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)  # Only book1 borrowed in last 3 days


class LibraryTrendsTestCase(APITestCase):
    """Test library trends endpoint."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!'
        )
        
        # Create test data
        self.category = BookCategory.objects.create(name='Programming')
        
        self.book = Book.objects.create(
            isbn='9781234567890',
            title='Python Programming',
            author='John Doe',
            category=self.category,
            total_copies=5,
            available_copies=5
        )
        
        # Create borrowing records for trends
        for i in range(10):
            BorrowingRecord.objects.create(
                user=self.user,
                book=self.book,
                status='returned' if i < 5 else 'borrowed',
                borrow_date=timezone.now().date() - timedelta(days=i),
                return_date=timezone.now().date() - timedelta(days=i-7) if i < 5 else None
            )
        
        self.client.force_authenticate(user=self.user)
    
    def test_get_library_trends_default_period(self):
        """Test getting library trends with default period."""
        url = reverse('analytics:library_trends')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['period'], 'month')
        self.assertIn('borrowing_trends', response.data)
        self.assertIn('popular_categories', response.data)
        self.assertIn('popular_books', response.data)
        self.assertIn('summary', response.data)
    
    def test_get_library_trends_week_period(self):
        """Test getting library trends for week period."""
        url = reverse('analytics:library_trends')
        
        response = self.client.get(url, {'period': 'week'})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['period'], 'week')
        
        # Check date range is correct
        date_range = response.data['date_range']
        days_diff = (
            timezone.datetime.strptime(date_range['end'], '%Y-%m-%d').date() -
            timezone.datetime.strptime(date_range['start'], '%Y-%m-%d').date()
        ).days
        self.assertEqual(days_diff, 7)


class AdminDashboardTestCase(APITestCase):
    """Test admin dashboard endpoint."""
    
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
        
        # Create test data
        self.category = BookCategory.objects.create(name='Programming')
        
        self.book = Book.objects.create(
            isbn='9781234567890',
            title='Python Programming',
            author='John Doe',
            category=self.category,
            total_copies=5,
            available_copies=3
        )
        
        # Create borrowing record
        BorrowingRecord.objects.create(
            user=self.regular_user,
            book=self.book,
            status='borrowed',
            borrow_date=timezone.now().date()
        )
        
        # Create overdue record
        BorrowingRecord.objects.create(
            user=self.regular_user,
            book=self.book,
            status='borrowed',
            due_date=timezone.now().date() - timedelta(days=1)
        )
    
    def test_get_admin_dashboard_as_admin(self):
        """Test getting admin dashboard as admin."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('analytics:admin_dashboard')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Check system overview
        self.assertIn('system_overview', response.data)
        self.assertEqual(response.data['system_overview']['total_users'], 2)
        self.assertEqual(response.data['system_overview']['total_books'], 1)
        self.assertEqual(response.data['system_overview']['current_borrows'], 2)
        self.assertEqual(response.data['system_overview']['overdue_books'], 1)
        
        # Check other sections
        self.assertIn('recent_activity', response.data)
        self.assertIn('alerts', response.data)
        self.assertIn('top_statistics', response.data)
    
    def test_get_admin_dashboard_as_regular_user(self):
        """Test getting admin dashboard as regular user (should fail)."""
        self.client.force_authenticate(user=self.regular_user)
        url = reverse('analytics:admin_dashboard')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class ReportsTestCase(APITestCase):
    """Test admin report endpoints."""
    
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='AdminPass123!'
        )
        
        self.user1 = User.objects.create_user(
            username='user1',
            email='user1@example.com',
            password='User1Pass123!'
        )
        
        self.user2 = User.objects.create_user(
            username='user2',
            email='user2@example.com',
            password='User2Pass123!'
        )
        
        # Create test data
        self.category = BookCategory.objects.create(name='Programming')
        
        self.book1 = Book.objects.create(
            isbn='9781234567890',
            title='Popular Book',
            author='John Doe',
            category=self.category,
            total_copies=5,
            available_copies=2
        )
        
        self.book2 = Book.objects.create(
            isbn='9780987654321',
            title='Less Popular Book',
            author='Jane Smith',
            category=self.category,
            total_copies=3,
            available_copies=3
        )
        
        # Create borrowing records
        for i in range(10):
            BorrowingRecord.objects.create(
                user=self.user1 if i % 2 == 0 else self.user2,
                book=self.book1,
                status='returned' if i < 8 else 'borrowed',
                borrow_date=timezone.now().date() - timedelta(days=i),
                return_date=timezone.now().date() - timedelta(days=i-7) if i < 8 else None,
                due_date=timezone.now().date() - timedelta(days=i-14) if i >= 8 else timezone.now().date() + timedelta(days=7)
            )
        
        # Create some records for book2
        for i in range(3):
            BorrowingRecord.objects.create(
                user=self.user2,
                book=self.book2,
                status='returned',
                borrow_date=timezone.now().date() - timedelta(days=i*2),
                return_date=timezone.now().date() - timedelta(days=i*2-7)
            )
        
        self.client.force_authenticate(user=self.admin)
    
    def test_popular_books_report(self):
        """Test popular books report."""
        url = reverse('analytics:popular_books_report')
        
        response = self.client.get(url, {'days': '30', 'limit': '10'})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('popular_books', response.data)
        self.assertIn('category_distribution', response.data)
        
        # Check popular books
        popular_books = response.data['popular_books']
        self.assertGreater(len(popular_books), 0)
        self.assertEqual(popular_books[0]['book__title'], 'Popular Book')
        self.assertGreater(popular_books[0]['borrow_count'], 0)
    
    def test_overdue_books_report(self):
        """Test overdue books report."""
        url = reverse('analytics:overdue_books_report')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('summary', response.data)
        self.assertIn('overdue_by_category', response.data)
        self.assertIn('repeat_offenders', response.data)
        
        # Check summary
        self.assertGreater(response.data['summary']['total_overdue'], 0)
    
    def test_user_activity_report(self):
        """Test user activity report."""
        url = reverse('analytics:user_activity_report')
        
        response = self.client.get(url, {'days': '30'})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('user_summary', response.data)
        self.assertIn('user_type_distribution', response.data)
        self.assertIn('borrowing_by_user_type', response.data)
        self.assertIn('top_borrowers', response.data)
        
        # Check user summary
        self.assertEqual(response.data['user_summary']['total_users'], 3)  # admin + 2 users
        self.assertGreater(response.data['user_summary']['active_users'], 0)
