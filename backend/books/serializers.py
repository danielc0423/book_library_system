"""
Book serializers for the Library System API.
"""
from rest_framework import serializers
from django.db import transaction
from django.utils import timezone
from drf_spectacular.utils import extend_schema_field
from .models import Book, BookCategory, BorrowingRecord, BookStatistics
from authentication.models import CustomUser


class BookCategorySerializer(serializers.ModelSerializer):
    """Serializer for book categories."""
    subcategory_count = serializers.SerializerMethodField()
    book_count = serializers.SerializerMethodField()
    
    class Meta:
        model = BookCategory
        fields = ['id', 'name', 'parent', 'description', 'is_active',
                  'subcategory_count', 'book_count']
        read_only_fields = ['id', 'subcategory_count', 'book_count']
    
    @extend_schema_field(serializers.IntegerField)
    def get_subcategory_count(self, obj):
        return obj.subcategories.filter(is_active=True).count()
    
    @extend_schema_field(serializers.IntegerField)
    def get_book_count(self, obj):
        return obj.books.filter(is_active=True).count()


class BookCategoryTreeSerializer(serializers.ModelSerializer):
    """Serializer for category tree structure."""
    subcategories = serializers.SerializerMethodField()
    
    class Meta:
        model = BookCategory
        fields = ['id', 'name', 'description', 'subcategories']
    
    @extend_schema_field(serializers.ListField)
    def get_subcategories(self, obj):
        return BookCategoryTreeSerializer(
            obj.subcategories.filter(is_active=True), 
            many=True
        ).data


class BookListSerializer(serializers.ModelSerializer):
    """Serializer for book listings."""
    category_name = serializers.CharField(source='category.name', read_only=True)
    subcategory_name = serializers.CharField(source='subcategory.name', read_only=True)
    availability_status = serializers.SerializerMethodField()
    popularity_score = serializers.SerializerMethodField()
    
    class Meta:
        model = Book
        fields = ['book_id', 'isbn', 'title', 'author', 'category', 'category_name',
                  'subcategory', 'subcategory_name', 'publication_year', 
                  'available_copies', 'total_copies', 'availability_status',
                  'popularity_score']
        read_only_fields = ['book_id', 'availability_status', 'popularity_score']
    
    @extend_schema_field(serializers.CharField)
    def get_availability_status(self, obj):
        if obj.available_copies > 5:
            return 'available'
        elif obj.available_copies > 0:
            return 'limited'
        else:
            return 'unavailable'
    
    @extend_schema_field(serializers.FloatField)
    def get_popularity_score(self, obj):
        try:
            return float(obj.statistics.popularity_score)
        except:
            return 0.0


class BookDetailSerializer(serializers.ModelSerializer):
    """Detailed serializer for single book view."""
    category_data = BookCategorySerializer(source='category', read_only=True)
    subcategory_data = BookCategorySerializer(source='subcategory', read_only=True)
    statistics = serializers.SerializerMethodField()
    current_borrowers = serializers.SerializerMethodField()
    
    class Meta:
        model = Book
        fields = ['book_id', 'isbn', 'title', 'author', 'category', 'category_data',
                  'subcategory', 'subcategory_data', 'publication_year', 
                  'publisher', 'description', 'total_copies', 'available_copies',
                  'location', 'created_date', 'is_active', 'statistics',
                  'current_borrowers']
        read_only_fields = ['book_id', 'created_date', 'statistics', 'current_borrowers']
    
    @extend_schema_field(serializers.DictField)
    def get_statistics(self, obj):
        try:
            stats = obj.statistics
            return {
                'total_borrowed': stats.total_borrowed_count,
                'currently_borrowed': stats.current_borrowed_count,
                'average_duration_days': float(stats.average_borrowing_duration),
                'popularity_score': float(stats.popularity_score),
                'last_borrowed': stats.last_borrowed_date
            }
        except:
            return None
    
    @extend_schema_field(serializers.ListField)
    def get_current_borrowers(self, obj):
        # Only show to staff
        user = self.context.get('request').user
        if user and user.is_staff:
            borrowers = obj.borrowing_records.filter(
                status='borrowed'
            ).select_related('user').values(
                'user__username', 'user__email', 'borrow_date', 'due_date'
            )
            return list(borrowers)
        return None


class BookCreateUpdateSerializer(serializers.ModelSerializer):
    """Serializer for creating/updating books (admin only)."""
    class Meta:
        model = Book
        fields = ['isbn', 'title', 'author', 'category', 'subcategory',
                  'publication_year', 'publisher', 'description', 
                  'total_copies', 'location', 'is_active']
    
    def validate_isbn(self, value):
        # Basic ISBN validation
        if len(value) not in [10, 13]:
            raise serializers.ValidationError("ISBN must be 10 or 13 characters.")
        return value
    
    def validate(self, attrs):
        # Ensure subcategory belongs to category
        if 'subcategory' in attrs and 'category' in attrs:
            if attrs['subcategory'] and attrs['subcategory'].parent != attrs['category']:
                raise serializers.ValidationError({
                    'subcategory': 'Subcategory must belong to the selected category.'
                })
        return attrs
    
    def create(self, validated_data):
        validated_data['available_copies'] = validated_data.get('total_copies', 0)
        return super().create(validated_data)


class BorrowingRecordSerializer(serializers.ModelSerializer):
    """Serializer for borrowing records."""
    book_title = serializers.CharField(source='book.title', read_only=True)
    book_isbn = serializers.CharField(source='book.isbn', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    days_overdue = serializers.SerializerMethodField()
    can_renew = serializers.SerializerMethodField()
    
    class Meta:
        model = BorrowingRecord
        fields = ['record_id', 'book', 'book_title', 'book_isbn', 'user', 'username',
                  'borrow_date', 'due_date', 'return_date', 'status', 
                  'late_fees', 'renewal_count', 'days_overdue', 'can_renew',
                  'notes']
        read_only_fields = ['record_id', 'user', 'borrow_date', 'late_fees', 
                           'days_overdue', 'can_renew']
    
    @extend_schema_field(serializers.IntegerField)
    def get_days_overdue(self, obj):
        return obj.days_overdue
    
    @extend_schema_field(serializers.BooleanField)
    def get_can_renew(self, obj):
        return obj.can_renew()


class BorrowBookSerializer(serializers.Serializer):
    """Serializer for borrowing a book."""
    book_id = serializers.UUIDField(required=True)
    notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_book_id(self, value):
        try:
            book = Book.objects.get(book_id=value, is_active=True)
            if book.available_copies <= 0:
                raise serializers.ValidationError("This book is not available for borrowing.")
        except Book.DoesNotExist:
            raise serializers.ValidationError("Book not found.")
        return value
    
    def validate(self, attrs):
        user = self.context['request'].user
        
        # Check if user can borrow more books
        if not user.can_borrow_more_books():
            raise serializers.ValidationError(
                f"You have reached your borrowing limit of {user.get_borrowing_limit()} books."
            )
        
        # Check if user already has this book
        book_id = attrs['book_id']
        if BorrowingRecord.objects.filter(
            user=user, 
            book_id=book_id, 
            status='borrowed'
        ).exists():
            raise serializers.ValidationError("You have already borrowed this book.")
        
        return attrs
    
    @transaction.atomic
    def create(self, validated_data):
        user = self.context['request'].user
        book = Book.objects.select_for_update().get(book_id=validated_data['book_id'])
        
        # Double-check availability with lock
        if book.available_copies <= 0:
            raise serializers.ValidationError("This book is no longer available.")
        
        # Create borrowing record
        record = BorrowingRecord.objects.create(
            user=user,
            book=book,
            notes=validated_data.get('notes', '')
        )
        
        # Update book availability
        book.borrow()
        
        return record


class BulkBorrowSerializer(serializers.Serializer):
    """Serializer for borrowing multiple books."""
    book_ids = serializers.ListField(
        child=serializers.UUIDField(),
        min_length=1,
        max_length=10
    )
    notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_book_ids(self, value):
        # Remove duplicates
        book_ids = list(set(value))
        
        # Check if all books exist and are available
        books = Book.objects.filter(book_id__in=book_ids, is_active=True)
        if books.count() != len(book_ids):
            raise serializers.ValidationError("One or more books not found.")
        
        unavailable_books = books.filter(available_copies=0)
        if unavailable_books.exists():
            unavailable_titles = list(unavailable_books.values_list('title', flat=True))
            raise serializers.ValidationError(
                f"The following books are not available: {', '.join(unavailable_titles)}"
            )
        
        return book_ids
    
    def validate(self, attrs):
        user = self.context['request'].user
        book_ids = attrs['book_ids']
        
        # Check borrowing limit
        current_borrowed = user.borrowing_records.filter(status='borrowed').count()
        total_after_borrow = current_borrowed + len(book_ids)
        borrowing_limit = user.get_borrowing_limit()
        
        if total_after_borrow > borrowing_limit:
            raise serializers.ValidationError(
                f"Borrowing {len(book_ids)} books would exceed your limit. "
                f"You can borrow {borrowing_limit - current_borrowed} more books."
            )
        
        # Check for already borrowed books
        already_borrowed = BorrowingRecord.objects.filter(
            user=user,
            book_id__in=book_ids,
            status='borrowed'
        ).values_list('book__title', flat=True)
        
        if already_borrowed:
            raise serializers.ValidationError(
                f"You have already borrowed: {', '.join(already_borrowed)}"
            )
        
        return attrs


class ReturnBookSerializer(serializers.Serializer):
    """Serializer for returning a book."""
    record_id = serializers.UUIDField(required=True)
    condition_notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_record_id(self, value):
        user = self.context['request'].user
        try:
            record = BorrowingRecord.objects.get(
                record_id=value,
                user=user,
                status='borrowed'
            )
        except BorrowingRecord.DoesNotExist:
            raise serializers.ValidationError("Borrowing record not found or already returned.")
        return value


class RenewBookSerializer(serializers.Serializer):
    """Serializer for renewing a book."""
    record_id = serializers.UUIDField(required=True)
    
    def validate_record_id(self, value):
        user = self.context['request'].user
        try:
            record = BorrowingRecord.objects.get(
                record_id=value,
                user=user,
                status='borrowed'
            )
            if not record.can_renew():
                if record.renewal_count >= record.max_renewals:
                    raise serializers.ValidationError(
                        f"Maximum renewal limit ({record.max_renewals}) reached."
                    )
                elif record.is_overdue():
                    raise serializers.ValidationError(
                        "Cannot renew overdue books. Please return the book first."
                    )
        except BorrowingRecord.DoesNotExist:
            raise serializers.ValidationError("Borrowing record not found.")
        return value


class BookSearchSerializer(serializers.Serializer):
    """Serializer for advanced book search."""
    query = serializers.CharField(required=False, allow_blank=True)
    title = serializers.CharField(required=False, allow_blank=True)
    author = serializers.CharField(required=False, allow_blank=True)
    isbn = serializers.CharField(required=False, allow_blank=True)
    category = serializers.UUIDField(required=False)
    subcategory = serializers.UUIDField(required=False)
    year_from = serializers.IntegerField(required=False, min_value=1000, max_value=2100)
    year_to = serializers.IntegerField(required=False, min_value=1000, max_value=2100)
    available_only = serializers.BooleanField(default=False)
    
    def validate(self, attrs):
        if attrs.get('year_from') and attrs.get('year_to'):
            if attrs['year_from'] > attrs['year_to']:
                raise serializers.ValidationError({
                    'year_from': 'From year must be less than or equal to To year.'
                })
        return attrs
