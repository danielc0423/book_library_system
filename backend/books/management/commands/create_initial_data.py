"""
Management command to create initial data for the library system.
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from books.models import Book, BookCategory, BookStatistics
from notifications.models import NotificationTemplate
import random

User = get_user_model()


class Command(BaseCommand):
    help = 'Creates initial data for the library system'

    def handle(self, *args, **options):
        self.stdout.write('Creating initial data...')
        
        # Create categories
        self.create_categories()
        
        # Create notification templates
        self.create_notification_templates()
        
        # Create sample books
        self.create_sample_books()
        
        # Create demo users
        self.create_demo_users()
        
        self.stdout.write(self.style.SUCCESS('Initial data created successfully!'))
    
    def create_categories(self):
        """Create book categories and subcategories."""
        categories_data = {
            'Fiction': ['Science Fiction', 'Fantasy', 'Mystery', 'Romance', 'Thriller'],
            'Non-Fiction': ['Biography', 'History', 'Science', 'Technology', 'Self-Help'],
            'Academic': ['Computer Science', 'Mathematics', 'Physics', 'Chemistry', 'Biology'],
            'Literature': ['Classic', 'Contemporary', 'Poetry', 'Drama', 'Essays'],
            'Reference': ['Dictionary', 'Encyclopedia', 'Atlas', 'Manual', 'Guide']
        }
        
        for main_cat, subcats in categories_data.items():
            parent, created = BookCategory.objects.get_or_create(
                name=main_cat,
                defaults={'description': f'{main_cat} books'}
            )
            if created:
                self.stdout.write(f'Created category: {main_cat}')
            
            for subcat in subcats:
                sub, created = BookCategory.objects.get_or_create(
                    name=subcat,
                    parent=parent,
                    defaults={'description': f'{subcat} books'}
                )
                if created:
                    self.stdout.write(f'  Created subcategory: {subcat}')
    
    def create_notification_templates(self):
        """Create email notification templates."""
        templates = [
            {
                'name': 'Welcome Email',
                'template_type': 'welcome',
                'subject': 'Welcome to the Library System!',
                'html_template': '''
                    <h2>Welcome {user_name}!</h2>
                    <p>Thank you for joining our library system.</p>
                    <p>You can now borrow up to 5 books at a time.</p>
                    <p>Happy reading!</p>
                ''',
                'text_template': '''
                    Welcome {user_name}!
                    
                    Thank you for joining our library system.
                    You can now borrow up to 5 books at a time.
                    
                    Happy reading!
                ''',
                'variables': ['user_name', 'email']
            },
            {
                'name': 'Borrowing Confirmation',
                'template_type': 'borrow_confirmation',
                'subject': 'Book Borrowed: {book_title}',
                'html_template': '''
                    <h3>Borrowing Confirmation</h3>
                    <p>You have successfully borrowed:</p>
                    <p><strong>{book_title}</strong></p>
                    <p>Borrow Date: {borrow_date}</p>
                    <p>Due Date: {due_date}</p>
                    <p>Please return the book by the due date to avoid late fees.</p>
                ''',
                'text_template': '''
                    Borrowing Confirmation
                    
                    You have successfully borrowed: {book_title}
                    Borrow Date: {borrow_date}
                    Due Date: {due_date}
                    
                    Please return the book by the due date to avoid late fees.
                ''',
                'variables': ['book_title', 'borrow_date', 'due_date']
            },
            {
                'name': 'Pre-Due Reminder',
                'template_type': 'pre_due_reminder',
                'subject': 'Reminder: {book_title} is due in {days_until_due} days',
                'html_template': '''
                    <h3>Book Due Soon</h3>
                    <p>This is a reminder that your borrowed book is due soon:</p>
                    <p><strong>{book_title}</strong></p>
                    <p>Due Date: {due_date}</p>
                    <p>Days remaining: {days_until_due}</p>
                    <p>Please return or renew the book to avoid late fees.</p>
                ''',
                'text_template': '''
                    Book Due Soon
                    
                    This is a reminder that your borrowed book is due soon:
                    {book_title}
                    Due Date: {due_date}
                    Days remaining: {days_until_due}
                    
                    Please return or renew the book to avoid late fees.
                ''',
                'variables': ['book_title', 'due_date', 'days_until_due']
            },
            {
                'name': 'Overdue Notice',
                'template_type': 'overdue_notice',
                'subject': 'Overdue: {book_title} - ${late_fee} fee',
                'html_template': '''
                    <h3>Overdue Book Notice</h3>
                    <p>The following book is overdue:</p>
                    <p><strong>{book_title}</strong></p>
                    <p>Due Date: {due_date}</p>
                    <p>Days Overdue: {days_overdue}</p>
                    <p>Current Late Fee: ${late_fee}</p>
                    <p>Please return the book as soon as possible.</p>
                ''',
                'text_template': '''
                    Overdue Book Notice
                    
                    The following book is overdue:
                    {book_title}
                    Due Date: {due_date}
                    Days Overdue: {days_overdue}
                    Current Late Fee: ${late_fee}
                    
                    Please return the book as soon as possible.
                ''',
                'variables': ['book_title', 'due_date', 'days_overdue', 'late_fee']
            },
            {
                'name': 'Return Confirmation',
                'template_type': 'return_confirmation',
                'subject': 'Book Returned: {book_title}',
                'html_template': '''
                    <h3>Return Confirmation</h3>
                    <p>You have successfully returned:</p>
                    <p><strong>{book_title}</strong></p>
                    <p>Return Date: {return_date}</p>
                    {late_fee and '<p>Late Fee: ${late_fee}</p>' or ''}
                    <p>Thank you for using our library!</p>
                ''',
                'text_template': '''
                    Return Confirmation
                    
                    You have successfully returned: {book_title}
                    Return Date: {return_date}
                    {late_fee and 'Late Fee: ${late_fee}' or ''}
                    
                    Thank you for using our library!
                ''',
                'variables': ['book_title', 'return_date', 'late_fee']
            }
        ]
        
        for template_data in templates:
            template, created = NotificationTemplate.objects.get_or_create(
                template_type=template_data['template_type'],
                defaults=template_data
            )
            if created:
                self.stdout.write(f'Created template: {template_data["name"]}')
    
    def create_sample_books(self):
        """Create sample books for testing."""
        books_data = [
            # Science Fiction
            {
                'isbn': '9780441013593',
                'title': 'Dune',
                'author': 'Frank Herbert',
                'category': 'Science Fiction',
                'publication_year': 1965,
                'publisher': 'Ace Books',
                'description': 'A science fiction novel about politics, religion, and ecology on the desert planet Arrakis.',
                'total_copies': 5,
                'location': 'SF-A-101'
            },
            {
                'isbn': '9780345342966',
                'title': 'Foundation',
                'author': 'Isaac Asimov',
                'category': 'Science Fiction',
                'publication_year': 1951,
                'publisher': 'Gnome Press',
                'description': 'The first novel in the Foundation series about the fall and rise of galactic empires.',
                'total_copies': 4,
                'location': 'SF-A-102'
            },
            # Computer Science
            {
                'isbn': '9780262033848',
                'title': 'Introduction to Algorithms',
                'author': 'Thomas H. Cormen',
                'category': 'Computer Science',
                'publication_year': 2009,
                'publisher': 'MIT Press',
                'description': 'Comprehensive textbook on algorithms and data structures.',
                'total_copies': 10,
                'location': 'CS-B-201'
            },
            {
                'isbn': '9780134685991',
                'title': 'Effective Java',
                'author': 'Joshua Bloch',
                'category': 'Computer Science',
                'publication_year': 2018,
                'publisher': 'Addison-Wesley',
                'description': 'Best practices for the Java programming language.',
                'total_copies': 6,
                'location': 'CS-B-202'
            },
            # Classic Literature
            {
                'isbn': '9780141439518',
                'title': 'Pride and Prejudice',
                'author': 'Jane Austen',
                'category': 'Classic',
                'publication_year': 1813,
                'publisher': 'Penguin Classics',
                'description': 'A romantic novel of manners set in Georgian England.',
                'total_copies': 8,
                'location': 'LIT-C-301'
            },
            {
                'isbn': '9780060850524',
                'title': 'To Kill a Mockingbird',
                'author': 'Harper Lee',
                'category': 'Classic',
                'publication_year': 1960,
                'publisher': 'J. B. Lippincott & Co.',
                'description': 'A novel about racial injustice in the American South.',
                'total_copies': 7,
                'location': 'LIT-C-302'
            },
            # History
            {
                'isbn': '9780670020553',
                'title': 'Sapiens: A Brief History of Humankind',
                'author': 'Yuval Noah Harari',
                'category': 'History',
                'publication_year': 2011,
                'publisher': 'Harvill Secker',
                'description': 'A narrative history of humanity from the Stone Age to the modern era.',
                'total_copies': 5,
                'location': 'HIS-D-401'
            },
            # Self-Help
            {
                'isbn': '9781501111105',
                'title': 'Atomic Habits',
                'author': 'James Clear',
                'category': 'Self-Help',
                'publication_year': 2018,
                'publisher': 'Avery',
                'description': 'A guide to building good habits and breaking bad ones.',
                'total_copies': 6,
                'location': 'SH-E-501'
            }
        ]
        
        for book_data in books_data:
            category_name = book_data.pop('category')
            category = BookCategory.objects.get(name=category_name)
            
            book, created = Book.objects.get_or_create(
                isbn=book_data['isbn'],
                defaults={
                    **book_data,
                    'category': category,
                    'available_copies': book_data['total_copies']
                }
            )
            if created:
                # Create statistics for the book
                BookStatistics.objects.create(book=book)
                self.stdout.write(f'Created book: {book.title}')
    
    def create_demo_users(self):
        """Create demo users for testing."""
        demo_users = [
            {
                'username': 'admin',
                'email': 'admin@library.com',
                'first_name': 'Admin',
                'last_name': 'User',
                'is_staff': True,
                'is_superuser': True,
                'user_type': 'admin',
                'max_books_allowed': 20
            },
            {
                'username': 'john_doe',
                'email': 'john.doe@example.com',
                'first_name': 'John',
                'last_name': 'Doe',
                'user_type': 'student',
                'max_books_allowed': 5,
                'phone_number': '+1234567890'
            },
            {
                'username': 'jane_smith',
                'email': 'jane.smith@example.com',
                'first_name': 'Jane',
                'last_name': 'Smith',
                'user_type': 'faculty',
                'max_books_allowed': 10,
                'phone_number': '+1234567891'
            },
            {
                'username': 'bob_wilson',
                'email': 'bob.wilson@example.com',
                'first_name': 'Bob',
                'last_name': 'Wilson',
                'user_type': 'staff',
                'max_books_allowed': 7,
                'phone_number': '+1234567892'
            }
        ]
        
        for user_data in demo_users:
            password = user_data.get('password', 'demo123456')
            is_superuser = user_data.pop('is_superuser', False)
            is_staff = user_data.pop('is_staff', False)
            
            user, created = User.objects.get_or_create(
                username=user_data['username'],
                defaults={
                    **user_data,
                    'email_verified': True,
                    'is_staff': is_staff,
                    'is_superuser': is_superuser
                }
            )
            
            if created:
                user.set_password(password)
                user.save()
                self.stdout.write(f'Created user: {user.username} (password: {password})')
