"""
Book API tests.
"""
from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from decimal import Decimal
from datetime import timedelta
import uuid
from .models import Book, BookCategory, BorrowingRecord, BookStatistics
from analytics.models import UserCreditScore

User = get_user_model()


class BookCategoryTestCase(APITestCase):
    """Test book category endpoints."""
    
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
        
        # Create categories
        self.parent_category = BookCategory.objects.create(
            name='Programming',
            description='Programming books'
        )
        self.child_category = BookCategory.objects.create(
            name='Python',
            parent=self.parent_category,
            description='Python programming books'
        )
    
    def test_list_categories(self):
        """Test listing categories."""
        self.client.force_authenticate(user=self.regular_user)
        url = reverse('books:categories-list')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 2)
    
    def test_get_category_tree(self):
        """Test getting category tree structure."""
        self.client.force_authenticate(user=self.regular_user)
        url = reverse('books:categories-tree')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)  # Only root category
        self.assertEqual(response.data[0]['name'], 'Programming')
        self.assertEqual(len(response.data[0]['subcategories']), 1)
    
    def test_create_category_as_admin(self):
        """Test creating category as admin."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('books:categories-list')
        
        data = {
            'name': 'Data Science',
            'description': 'Data Science books'
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(BookCategory.objects.count(), 3)
    
    def test_create_category_as_regular_user(self):
        """Test creating category as regular user (should fail)."""
        self.client.force_authenticate(user=self.regular_user)
        url = reverse('books:categories-list')
        
        data = {
            'name': 'Data Science',
            'description': 'Data Science books'
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class BookViewSetTestCase(APITestCase):
    """Test book management endpoints."""
    
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='AdminPass123!'
        )
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!'
        )
        
        # Create categories
        self.category = BookCategory.objects.create(name='Programming')
        self.subcategory = BookCategory.objects.create(
            name='Python',
            parent=self.category
        )
        
        # Create books
        self.book1 = Book.objects.create(
            isbn='9781234567890',
            title='Python Programming',
            author='John Doe',
            category=self.category,
            subcategory=self.subcategory,
            publication_year=2023,
            publisher='Tech Publishers',
            description='Learn Python programming',
            total_copies=5,
            available_copies=5,
            location='Shelf A1'
        )
        
        self.book2 = Book.objects.create(
            isbn='9780987654321',
            title='Django Web Development',
            author='Jane Smith',
            category=self.category,
            publication_year=2023,
            publisher='Web Publishers',
            description='Build web apps with Django',
            total_copies=3,
            available_copies=0,
            location='Shelf A2'
        )
        
        # Create statistics
        BookStatistics.objects.create(
            book=self.book1,
            total_borrowed_count=10,
            popularity_score=85.5
        )
    
    def test_list_books(self):
        """Test listing books."""
        self.client.force_authenticate(user=self.user)
        url = reverse('books:books-list')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 2)
    
    def test_list_available_books_only(self):
        """Test listing only available books."""
        self.client.force_authenticate(user=self.user)
        url = reverse('books:books-list')
        
        response = self.client.get(url, {'available_only': 'true'})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['results'][0]['title'], 'Python Programming')
    
    def test_search_books(self):
        """Test searching books."""
        self.client.force_authenticate(user=self.user)
        url = reverse('books:books-list')
        
        response = self.client.get(url, {'search': 'Python'})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['results'][0]['title'], 'Python Programming')
    
    def test_get_book_detail(self):
        """Test getting book details."""
        self.client.force_authenticate(user=self.user)
        url = reverse('books:books-detail', kwargs={'pk': self.book1.id})
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['title'], 'Python Programming')
        self.assertIn('statistics', response.data)
        self.assertIn('category_data', response.data)
    
    def test_get_popular_books(self):
        """Test getting popular books."""
        self.client.force_authenticate(user=self.user)
        url = reverse('books:books-popular')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['title'], 'Python Programming')
    
    def test_advanced_search(self):
        """Test advanced book search."""
        self.client.force_authenticate(user=self.user)
        url = reverse('books:books-search')
        
        data = {
            'query': 'Programming',
            'year_from': 2023,
            'year_to': 2024,
            'available_only': True
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
    
    def test_create_book_as_admin(self):
        """Test creating book as admin."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('books:books-list')
        
        data = {
            'isbn': '9781111111111',
            'title': 'New Book',
            'author': 'New Author',
            'category': str(self.category.id),
            'publication_year': 2024,
            'publisher': 'New Publisher',
            'description': 'New book description',
            'total_copies': 10,
            'location': 'Shelf B1'
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Book.objects.count(), 3)
        
        # Verify available copies equals total copies
        new_book = Book.objects.get(isbn='9781111111111')
        self.assertEqual(new_book.available_copies, 10)
    
    def test_update_book_as_admin(self):
        """Test updating book as admin."""
        self.client.force_authenticate(user=self.admin)
        url = reverse('books:books-detail', kwargs={'pk': self.book1.id})
        
        data = {
            'total_copies': 10,
            'location': 'Shelf B2'
        }
        
        response = self.client.patch(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.book1.refresh_from_db()
        self.assertEqual(self.book1.total_copies, 10)
        self.assertEqual(self.book1.location, 'Shelf B2')


class BorrowingTestCase(APITestCase):
    """Test borrowing operation endpoints."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='TestPass123!',
            user_type='student',
            max_books_allowed=5
        )
        
        # Create credit score
        UserCreditScore.objects.create(user=self.user)
        
        # Create category and books
        self.category = BookCategory.objects.create(name='Programming')
        
        self.book1 = Book.objects.create(
            isbn='9781234567890',
            title='Book 1',
            author='Author 1',
            category=self.category,
            total_copies=5,
            available_copies=5
        )
        
        self.book2 = Book.objects.create(
            isbn='9780987654321',
            title='Book 2',
            author='Author 2',
            category=self.category,
            total_copies=3,
            available_copies=3
        )
        
        self.book3 = Book.objects.create(
            isbn='9781111111111',
            title='Book 3',
            author='Author 3',
            category=self.category,
            total_copies=1,
            available_copies=0  # Not available
        )
        
        self.client.force_authenticate(user=self.user)
    
    def test_borrow_book_success(self):
        """Test successful book borrowing."""
        url = reverse('books:borrow_book')
        
        data = {
            'book_id': str(self.book1.id),
            'notes': 'Handle with care'
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('due_date', response.data)
        
        # Verify book availability decreased
        self.book1.refresh_from_db()
        self.assertEqual(self.book1.available_copies, 4)
        
        # Verify borrowing record created
        record = BorrowingRecord.objects.get(user=self.user, book=self.book1)
        self.assertEqual(record.status, 'borrowed')
    
    def test_borrow_unavailable_book(self):
        """Test borrowing unavailable book."""
        url = reverse('books:borrow_book')
        
        data = {
            'book_id': str(self.book3.id)
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('book_id', response.data)
    
    def test_borrow_same_book_twice(self):
        """Test borrowing same book twice."""
        # First borrow
        BorrowingRecord.objects.create(
            user=self.user,
            book=self.book1,
            status='borrowed'
        )
        
        url = reverse('books:borrow_book')
        data = {
            'book_id': str(self.book1.id)
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
    
    def test_bulk_borrow_books(self):
        """Test bulk borrowing books."""
        url = reverse('books:bulk_borrow')
        
        data = {
            'book_ids': [str(self.book1.id), str(self.book2.id)],
            'notes': 'Borrowed for research'
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(response.data['records']), 2)
        
        # Verify books availability
        self.book1.refresh_from_db()
        self.book2.refresh_from_db()
        self.assertEqual(self.book1.available_copies, 4)
        self.assertEqual(self.book2.available_copies, 2)
    
    def test_exceed_borrowing_limit(self):
        """Test exceeding borrowing limit."""
        # Create existing borrows to reach limit
        for i in range(5):
            book = Book.objects.create(
                isbn=f'978000000{i:04d}',
                title=f'Book {i}',
                author='Author',
                category=self.category,
                total_copies=1,
                available_copies=1
            )
            BorrowingRecord.objects.create(
                user=self.user,
                book=book,
                status='borrowed'
            )
        
        url = reverse('books:borrow_book')
        data = {
            'book_id': str(self.book1.id)
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('borrowing limit', str(response.data))
    
    def test_return_book(self):
        """Test returning a book."""
        # Create borrowing record
        record = BorrowingRecord.objects.create(
            user=self.user,
            book=self.book1,
            status='borrowed'
        )
        self.book1.available_copies = 4
        self.book1.save()
        
        url = reverse('books:return_book', kwargs={'record_id': record.id})
        data = {
            'condition_notes': 'Book in good condition'
        }
        
        response = self.client.put(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verify book returned
        record.refresh_from_db()
        self.assertEqual(record.status, 'returned')
        self.assertIsNotNone(record.return_date)
        
        # Verify book availability increased
        self.book1.refresh_from_db()
        self.assertEqual(self.book1.available_copies, 5)
    
    def test_renew_book(self):
        """Test renewing a book."""
        # Create borrowing record
        record = BorrowingRecord.objects.create(
            user=self.user,
            book=self.book1,
            status='borrowed',
            renewal_count=0
        )
        
        url = reverse('books:renew_book', kwargs={'record_id': record.id})
        
        response = self.client.put(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('new_due_date', response.data)
        
        # Verify renewal
        record.refresh_from_db()
        self.assertEqual(record.renewal_count, 1)
    
    def test_renew_overdue_book(self):
        """Test renewing overdue book (should fail)."""
        # Create overdue borrowing record
        record = BorrowingRecord.objects.create(
            user=self.user,
            book=self.book1,
            status='borrowed',
            due_date=timezone.now().date() - timedelta(days=1)
        )
        
        url = reverse('books:renew_book', kwargs={'record_id': record.id})
        
        response = self.client.put(url)
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('overdue', str(response.data))
    
    def test_get_current_borrowed_books(self):
        """Test getting current borrowed books."""
        # Create borrowing records
        BorrowingRecord.objects.create(
            user=self.user,
            book=self.book1,
            status='borrowed'
        )
        BorrowingRecord.objects.create(
            user=self.user,
            book=self.book2,
            status='returned'
        )
        
        url = reverse('books:current_borrowed')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['results'][0]['book_title'], 'Book 1')
    
    def test_get_borrowing_history(self):
        """Test getting borrowing history."""
        # Create borrowing records
        BorrowingRecord.objects.create(
            user=self.user,
            book=self.book1,
            status='borrowed'
        )
        BorrowingRecord.objects.create(
            user=self.user,
            book=self.book2,
            status='returned'
        )
        
        url = reverse('books:borrowing_history')
        
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 2)
