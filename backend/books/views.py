"""
Book views for the Library System API.
"""
from rest_framework import generics, status, permissions, viewsets, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q, Count, Avg, F
from django.db import transaction
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from .models import Book, BookCategory, BorrowingRecord, BookStatistics
from .serializers import (
    BookListSerializer, BookDetailSerializer, BookCreateUpdateSerializer,
    BookCategorySerializer, BookCategoryTreeSerializer,
    BorrowingRecordSerializer, BorrowBookSerializer, BulkBorrowSerializer,
    ReturnBookSerializer, RenewBookSerializer, BookSearchSerializer
)
from .permissions import IsOwnerOrAdmin, IsAdminOrReadOnly
from analytics.tasks import update_user_credit_score
from notifications.tasks import send_notification


class BookCategoryViewSet(viewsets.ModelViewSet):
    """Book category management."""
    queryset = BookCategory.objects.filter(is_active=True)
    serializer_class = BookCategorySerializer
    permission_classes = [IsAdminOrReadOnly]
    filterset_fields = ['parent']
    search_fields = ['name', 'description']
    ordering = ['name']
    
    @action(detail=False, methods=['get'])
    def tree(self, request):
        """Get category tree structure."""
        # Get root categories (no parent)
        root_categories = BookCategory.objects.filter(
            parent__isnull=True,
            is_active=True
        )
        serializer = BookCategoryTreeSerializer(root_categories, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def books(self, request, pk=None):
        """Get all books in this category."""
        category = self.get_object()
        books = Book.objects.filter(
            Q(category=category) | Q(subcategory=category),
            is_active=True
        )
        
        # Apply pagination
        page = self.paginate_queryset(books)
        if page is not None:
            serializer = BookListSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        serializer = BookListSerializer(books, many=True)
        return Response(serializer.data)


class BookViewSet(viewsets.ModelViewSet):
    """Book management endpoints."""
    queryset = Book.objects.filter(is_active=True).select_related(
        'category', 'subcategory', 'statistics'
    )
    permission_classes = [IsAdminOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'subcategory', 'publication_year']
    search_fields = ['title', 'author', 'isbn', 'description']
    ordering_fields = ['title', 'author', 'publication_year', 'created_date']
    ordering = ['title']
    
    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            return BookCreateUpdateSerializer
        elif self.action == 'retrieve':
            return BookDetailSerializer
        return BookListSerializer
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filter available books only if requested
        available_only = self.request.query_params.get('available_only', 'false').lower() == 'true'
        if available_only:
            queryset = queryset.filter(available_copies__gt=0)
        
        return queryset
    
    @action(detail=False, methods=['get'])
    def popular(self, request):
        """Get popular books based on borrowing statistics."""
        limit = int(request.query_params.get('limit', 10))
        
        popular_books = self.get_queryset().filter(
            statistics__isnull=False
        ).order_by('-statistics__popularity_score')[:limit]
        
        serializer = BookListSerializer(popular_books, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def recommendations(self, request):
        """Get personalized book recommendations."""
        if not request.user.is_authenticated:
            return Response({
                'error': 'Authentication required for recommendations.'
            }, status=status.HTTP_401_UNAUTHORIZED)
        
        # Get user's borrowing history
        user_categories = BorrowingRecord.objects.filter(
            user=request.user
        ).values('book__category').annotate(
            count=Count('id')
        ).order_by('-count')[:3]
        
        category_ids = [cat['book__category'] for cat in user_categories]
        
        # Get books from favorite categories that user hasn't borrowed
        borrowed_books = BorrowingRecord.objects.filter(
            user=request.user
        ).values_list('book_id', flat=True)
        
        recommendations = self.get_queryset().filter(
            category_id__in=category_ids,
            available_copies__gt=0
        ).exclude(
            id__in=borrowed_books
        ).order_by('-statistics__popularity_score')[:10]
        
        serializer = BookListSerializer(recommendations, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def search(self, request):
        """Advanced book search."""
        serializer = BookSearchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        queryset = self.get_queryset()
        data = serializer.validated_data
        
        # General query search
        if data.get('query'):
            query = data['query']
            queryset = queryset.filter(
                Q(title__icontains=query) |
                Q(author__icontains=query) |
                Q(isbn__icontains=query) |
                Q(description__icontains=query)
            )
        
        # Specific field searches
        if data.get('title'):
            queryset = queryset.filter(title__icontains=data['title'])
        
        if data.get('author'):
            queryset = queryset.filter(author__icontains=data['author'])
        
        if data.get('isbn'):
            queryset = queryset.filter(isbn__icontains=data['isbn'])
        
        if data.get('category'):
            queryset = queryset.filter(category_id=data['category'])
        
        if data.get('subcategory'):
            queryset = queryset.filter(subcategory_id=data['subcategory'])
        
        # Year range
        if data.get('year_from'):
            queryset = queryset.filter(publication_year__gte=data['year_from'])
        
        if data.get('year_to'):
            queryset = queryset.filter(publication_year__lte=data['year_to'])
        
        # Available only
        if data.get('available_only'):
            queryset = queryset.filter(available_copies__gt=0)
        
        # Apply pagination
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = BookListSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        serializer = BookListSerializer(queryset, many=True)
        return Response(serializer.data)


class BorrowBookView(generics.CreateAPIView):
    """Borrow a single book."""
    serializer_class = BorrowBookSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        with transaction.atomic():
            borrowing_record = serializer.save()
        
        # Send confirmation notification
        send_notification.delay(
            user_id=request.user.id,
            template_name='book_borrowed',
            context={
                'user_name': request.user.get_full_name(),
                'book_title': borrowing_record.book.title,
                'due_date': borrowing_record.due_date.strftime('%B %d, %Y')
            }
        )
        
        response_serializer = BorrowingRecordSerializer(borrowing_record)
        return Response(
            response_serializer.data,
            status=status.HTTP_201_CREATED
        )


class BulkBorrowView(generics.CreateAPIView):
    """Borrow multiple books at once."""
    serializer_class = BulkBorrowSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        book_ids = serializer.validated_data['book_ids']
        notes = serializer.validated_data.get('notes', '')
        
        with transaction.atomic():
            borrowing_records = []
            
            for book_id in book_ids:
                book = Book.objects.select_for_update().get(book_id=book_id)
                
                # Create borrowing record
                record = BorrowingRecord.objects.create(
                    user=request.user,
                    book=book,
                    notes=notes
                )
                
                # Update book availability
                book.borrow()
                
                borrowing_records.append(record)
        
        # Send bulk confirmation
        book_titles = [record.book.title for record in borrowing_records]
        send_notification.delay(
            user_id=request.user.id,
            template_name='bulk_books_borrowed',
            context={
                'user_name': request.user.get_full_name(),
                'book_count': len(borrowing_records),
                'book_titles': book_titles,
                'due_date': borrowing_records[0].due_date.strftime('%B %d, %Y')
            }
        )
        
        response_serializer = BorrowingRecordSerializer(borrowing_records, many=True)
        return Response({
            'message': f'Successfully borrowed {len(borrowing_records)} books.',
            'records': response_serializer.data
        }, status=status.HTTP_201_CREATED)


class ReturnBookView(generics.UpdateAPIView):
    """Return a borrowed book."""
    permission_classes = [permissions.IsAuthenticated]
    
    def update(self, request, record_id, *args, **kwargs):
        try:
            record = BorrowingRecord.objects.select_for_update().get(
                record_id=record_id,
                user=request.user,
                status='borrowed'
            )
        except BorrowingRecord.DoesNotExist:
            return Response({
                'error': 'Borrowing record not found or already returned.'
            }, status=status.HTTP_404_NOT_FOUND)
        
        condition_notes = request.data.get('condition_notes', '')
        
        with transaction.atomic():
            # Process return
            record.process_return(condition_notes)
            
            # Update user credit score
            update_user_credit_score.delay(request.user.id)
        
        # Send return confirmation
        send_notification.delay(
            user_id=request.user.id,
            template_name='book_returned',
            context={
                'user_name': request.user.get_full_name(),
                'book_title': record.book.title,
                'late_fees': float(record.late_fees) if record.late_fees > 0 else 0
            }
        )
        
        serializer = BorrowingRecordSerializer(record)
        return Response({
            'message': 'Book returned successfully.',
            'record': serializer.data,
            'late_fees': float(record.late_fees)
        }, status=status.HTTP_200_OK)


class BulkReturnView(APIView):
    """Return multiple books at once."""
    permission_classes = [permissions.IsAuthenticated]
    
    def put(self, request, *args, **kwargs):
        record_ids = request.data.get('record_ids', [])
        condition_notes = request.data.get('condition_notes', '')
        
        if not record_ids:
            return Response({
                'error': 'No record IDs provided.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        returned_records = []
        total_late_fees = 0
        
        with transaction.atomic():
            for record_id in record_ids:
                try:
                    record = BorrowingRecord.objects.select_for_update().get(
                        record_id=record_id,
                        user=request.user,
                        status='borrowed'
                    )
                    
                    # Process return
                    record.process_return(condition_notes)
                    returned_records.append(record)
                    total_late_fees += float(record.late_fees)
                    
                except BorrowingRecord.DoesNotExist:
                    continue
            
            # Update credit score once for all returns
            if returned_records:
                update_user_credit_score.delay(request.user.id)
        
        if not returned_records:
            return Response({
                'error': 'No valid records found to return.'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Send bulk return notification
        book_titles = [record.book.title for record in returned_records]
        send_notification.delay(
            user_id=request.user.id,
            template_name='bulk_books_returned',
            context={
                'user_name': request.user.get_full_name(),
                'book_count': len(returned_records),
                'book_titles': book_titles,
                'total_late_fees': total_late_fees
            }
        )
        
        serializer = BorrowingRecordSerializer(returned_records, many=True)
        return Response({
            'message': f'Successfully returned {len(returned_records)} books.',
            'records': serializer.data,
            'total_late_fees': total_late_fees
        }, status=status.HTTP_200_OK)


class RenewBookView(generics.UpdateAPIView):
    """Renew a borrowed book."""
    permission_classes = [permissions.IsAuthenticated]
    
    def update(self, request, record_id, *args, **kwargs):
        try:
            record = BorrowingRecord.objects.get(
                record_id=record_id,
                user=request.user,
                status='borrowed'
            )
        except BorrowingRecord.DoesNotExist:
            return Response({
                'error': 'Borrowing record not found.'
            }, status=status.HTTP_404_NOT_FOUND)
        
        if not record.can_renew():
            error_message = 'Cannot renew this book. '
            if record.renewal_count >= record.max_renewals:
                error_message += f'Maximum renewal limit ({record.max_renewals}) reached.'
            elif record.is_overdue():
                error_message += 'Book is overdue. Please return it first.'
            
            return Response({
                'error': error_message
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Process renewal
        record.renew()
        
        # Send renewal confirmation
        send_notification.delay(
            user_id=request.user.id,
            template_name='book_renewed',
            context={
                'user_name': request.user.get_full_name(),
                'book_title': record.book.title,
                'new_due_date': record.due_date.strftime('%B %d, %Y'),
                'renewals_remaining': record.max_renewals - record.renewal_count
            }
        )
        
        serializer = BorrowingRecordSerializer(record)
        return Response({
            'message': 'Book renewed successfully.',
            'record': serializer.data,
            'new_due_date': record.due_date,
            'renewals_remaining': record.max_renewals - record.renewal_count
        }, status=status.HTTP_200_OK)


class CurrentBorrowedBooksView(generics.ListAPIView):
    """List current borrowed books for authenticated user."""
    serializer_class = BorrowingRecordSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return BorrowingRecord.objects.filter(
            user=self.request.user,
            status='borrowed'
        ).select_related('book').order_by('due_date')


class BorrowingHistoryView(generics.ListAPIView):
    """List borrowing history for authenticated user."""
    serializer_class = BorrowingRecordSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.OrderingFilter]
    ordering_fields = ['borrow_date', 'return_date', 'due_date']
    ordering = ['-borrow_date']
    
    def get_queryset(self):
        return BorrowingRecord.objects.filter(
            user=self.request.user
        ).select_related('book')


class OverdueBooksView(generics.ListAPIView):
    """List overdue books for authenticated user."""
    serializer_class = BorrowingRecordSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return BorrowingRecord.objects.filter(
            user=self.request.user,
            status='borrowed',
            due_date__lt=timezone.now().date()
        ).select_related('book').order_by('due_date')
