"""
Django management command to load fixture data for the library system.
Provides sample data for demonstration purposes.
"""
import os
import sys
from django.core.management.base import BaseCommand, CommandError
from django.core.management import call_command
from django.conf import settings
from django.db import transaction
from authentication.models import CustomUser
from books.models import BookCategory, Book
from pathlib import Path


class Command(BaseCommand):
    help = 'Load demo fixture data for the library system'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear all existing data before loading fixtures',
        )
        parser.add_argument(
            '--users-only',
            action='store_true',
            help='Load only user fixtures',
        )
        parser.add_argument(
            '--books-only',
            action='store_true',
            help='Load only book and category fixtures',
        )
        parser.add_argument(
            '--list',
            action='store_true',
            help='List available fixture files',
        )

    def handle(self, *args, **options):
        """Execute the command"""
        
        # Get the fixtures directory path
        fixtures_dir = Path(settings.BASE_DIR) / 'fixtures'
        
        if not fixtures_dir.exists():
            raise CommandError(f"Fixtures directory not found: {fixtures_dir}")
        
        # List available fixtures if requested
        if options['list']:
            self.list_fixtures(fixtures_dir)
            return
        
        # Check for available fixture files
        fixture_files = {
            'users': fixtures_dir / 'users.json',
            'categories': fixtures_dir / 'book_categories.json',
            'books': fixtures_dir / 'books.json',
            'borrowing_records': fixtures_dir / 'borrowing_records.json',
            'user_credit_scores': fixtures_dir / 'user_credit_scores.json',
        }
        
        # Validate fixture files exist
        missing_files = []
        for name, path in fixture_files.items():
            if not path.exists():
                missing_files.append(str(path))
        
        if missing_files:
            self.stdout.write(
                self.style.WARNING(
                    f"Warning: Missing fixture files: {', '.join(missing_files)}"
                )
            )
        
        # Clear existing data if requested
        if options['clear']:
            self.clear_data()
        
        # Load fixtures with transaction
        try:
            with transaction.atomic():
                if options['users_only']:
                    self.load_user_fixtures(fixture_files)
                elif options['books_only']:
                    self.load_book_fixtures(fixture_files)
                else:
                    self.load_all_fixtures(fixture_files)
            
            self.display_summary()
            
        except Exception as e:
            raise CommandError(f"Error loading fixtures: {str(e)}")

    def list_fixtures(self, fixtures_dir):
        """List all available fixture files"""
        self.stdout.write(
            self.style.SUCCESS("📦 Available Fixture Files:")
        )
        
        fixture_files = list(fixtures_dir.glob('*.json'))
        if not fixture_files:
            self.stdout.write("No fixture files found.")
            return
        
        for fixture_file in sorted(fixture_files):
            self.stdout.write(f"  📄 {fixture_file.name}")
        
        self.stdout.write(f"\n📁 Fixtures directory: {fixtures_dir}")

    def clear_data(self):
        """Clear existing data"""
        self.stdout.write("🗑️  Clearing existing data...")
        
        # Clear in reverse dependency order
        models_to_clear = [
            ('User Credit Scores', 'analytics.UserCreditScore'),
            ('Borrowing Records', 'books.BorrowingRecord'),
            ('Book Statistics', 'books.BookStatistics'),
            ('Books', 'books.Book'),
            ('Book Categories', 'books.BookCategory'),
            ('Users (non-superuser)', None),  # Handle users specially
        ]
        
        for model_name, model_path in models_to_clear:
            if model_path:
                app_label, model_name_only = model_path.split('.')
                try:
                    call_command('shell', '-c', 
                        f"from {app_label}.models import {model_name_only}; "
                        f"{model_name_only}.objects.all().delete()"
                    )
                    self.stdout.write(f"  ✅ Cleared {model_name}")
                except Exception as e:
                    self.stdout.write(
                        self.style.WARNING(f"  ⚠️  Could not clear {model_name}: {e}")
                    )
            else:
                # Handle users specially - keep superusers
                try:
                    deleted_count = CustomUser.objects.filter(is_superuser=False).delete()[0]
                    self.stdout.write(f"  ✅ Cleared {deleted_count} non-superuser accounts")
                except Exception as e:
                    self.stdout.write(
                        self.style.WARNING(f"  ⚠️  Could not clear users: {e}")
                    )

    def load_user_fixtures(self, fixture_files):
        """Load only user fixtures"""
        self.stdout.write("👥 Loading user fixtures...")
        
        if fixture_files['users'].exists():
            call_command('loaddata', str(fixture_files['users']))
            self.stdout.write("  ✅ Users loaded successfully")
        else:
            self.stdout.write("  ⚠️  Users fixture file not found")

    def load_book_fixtures(self, fixture_files):
        """Load book-related fixtures"""
        self.stdout.write("📚 Loading book fixtures...")
        
        # Load categories first (dependency order)
        if fixture_files['categories'].exists():
            call_command('loaddata', str(fixture_files['categories']))
            self.stdout.write("  ✅ Book categories loaded successfully")
        else:
            self.stdout.write("  ⚠️  Book categories fixture file not found")
        
        # Load books
        if fixture_files['books'].exists():
            call_command('loaddata', str(fixture_files['books']))
            self.stdout.write("  ✅ Books loaded successfully")
        else:
            self.stdout.write("  ⚠️  Books fixture file not found")

    def load_all_fixtures(self, fixture_files):
        """Load all fixtures in proper order"""
        self.stdout.write("🚀 Loading all fixtures...")
        
        # Load in dependency order
        self.load_user_fixtures(fixture_files)
        self.load_book_fixtures(fixture_files)
        self.load_transaction_fixtures(fixture_files)
        self.load_analytics_fixtures(fixture_files)

    def load_transaction_fixtures(self, fixture_files):
        """Load transaction-related fixtures"""
        self.stdout.write("📝 Loading transaction fixtures...")
        
        # Load borrowing records
        if fixture_files['borrowing_records'].exists():
            call_command('loaddata', str(fixture_files['borrowing_records']))
            self.stdout.write("  ✅ Borrowing records loaded successfully")
        else:
            self.stdout.write("  ⚠️  Borrowing records fixture file not found")

    def load_analytics_fixtures(self, fixture_files):
        """Load analytics-related fixtures"""
        self.stdout.write("📊 Loading analytics fixtures...")
        
        # Load user credit scores
        if fixture_files['user_credit_scores'].exists():
            call_command('loaddata', str(fixture_files['user_credit_scores']))
            self.stdout.write("  ✅ User credit scores loaded successfully")
        else:
            self.stdout.write("  ⚠️  User credit scores fixture file not found")

    def display_summary(self):
        """Display a summary of loaded data"""
        self.stdout.write("\n" + "="*50)
        self.stdout.write(self.style.SUCCESS("📊 FIXTURE LOADING COMPLETE"))
        self.stdout.write("="*50)
        
        # Count loaded data
        try:
            user_count = CustomUser.objects.count()
            category_count = BookCategory.objects.count()
            book_count = Book.objects.count()
            
            # Import models for counting
            from books.models import BorrowingRecord
            from analytics.models import UserCreditScore
            
            borrowing_count = BorrowingRecord.objects.count()
            credit_score_count = UserCreditScore.objects.count()
            
            self.stdout.write(f"👥 Users: {user_count}")
            self.stdout.write(f"📂 Categories: {category_count}")
            self.stdout.write(f"📚 Books: {book_count}")
            self.stdout.write(f"📝 Borrowing Records: {borrowing_count}")
            self.stdout.write(f"🏆 Credit Scores: {credit_score_count}")
            
        except Exception as e:
            self.stdout.write(
                self.style.WARNING(f"Could not count records: {e}")
            )
        
        # Display sample credentials
        self.stdout.write("\n" + "-"*50)
        self.stdout.write(self.style.SUCCESS("🔑 SAMPLE LOGIN CREDENTIALS"))
        self.stdout.write("-"*50)
        self.stdout.write("All users have password: 'demo123'")
        self.stdout.write("\nSample accounts:")
        
        sample_accounts = [
            ("admin", "System Administrator", "admin@library.edu"),
            ("john.smith", "John Smith (Student)", "john.smith@university.edu"),
            ("dr.wilson", "Dr. Sarah Wilson (Faculty)", "s.wilson@university.edu"),
            ("library.staff", "Emma Thompson (Staff)", "e.thompson@library.edu"),
        ]
        
        for username, name, email in sample_accounts:
            self.stdout.write(f"  👤 {username:15} | {name:25} | {email}")
        
        # Display API endpoints
        self.stdout.write("\n" + "-"*50)
        self.stdout.write(self.style.SUCCESS("🔗 USEFUL API ENDPOINTS"))
        self.stdout.write("-"*50)
        
        base_url = "http://localhost:8000"
        endpoints = [
            ("📋 API Documentation", f"{base_url}/api/v1/docs/"),
            ("🔐 User Registration UI", f"{base_url}/signup/"),
            ("📚 List Books", f"{base_url}/api/v1/books/books/"),
            ("👥 List Users (Admin)", f"{base_url}/api/v1/auth/users/"),
            ("📂 List Categories", f"{base_url}/api/v1/books/categories/"),
            ("🔍 Health Check", f"{base_url}/health/"),
        ]
        
        for desc, url in endpoints:
            self.stdout.write(f"  {desc:25} | {url}")
        
        # Display quick start commands
        self.stdout.write("\n" + "-"*50)
        self.stdout.write(self.style.SUCCESS("🚀 QUICK START COMMANDS"))
        self.stdout.write("-"*50)
        self.stdout.write("Start the development server:")
        self.stdout.write("  python manage.py runserver")
        self.stdout.write("\nCreate a new superuser:")
        self.stdout.write("  python manage.py createsuperuser")
        self.stdout.write("\nAccess the admin interface:")
        self.stdout.write("  http://localhost:8000/admin/")
        
        self.stdout.write("\n" + "="*50)
        self.stdout.write(
            self.style.SUCCESS("✨ Demo data loaded successfully! Happy testing! ✨")
        )
        self.stdout.write("="*50 + "\n")
