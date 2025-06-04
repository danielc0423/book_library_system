"""
Book URLs for the Library System API.
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    BookViewSet, BookCategoryViewSet,
    BorrowBookView, BulkBorrowView,
    ReturnBookView, BulkReturnView,
    RenewBookView, CurrentBorrowedBooksView,
    BorrowingHistoryView, OverdueBooksView
)

app_name = 'books'

# Create router for viewsets
router = DefaultRouter()
router.register(r'books', BookViewSet, basename='books')
router.register(r'categories', BookCategoryViewSet, basename='categories')

urlpatterns = [
    # Borrowing Operations
    path('borrow/', BorrowBookView.as_view(), name='borrow_book'),
    path('borrow/bulk/', BulkBorrowView.as_view(), name='bulk_borrow'),
    path('return/<uuid:record_id>/', ReturnBookView.as_view(), name='return_book'),
    path('return/bulk/', BulkReturnView.as_view(), name='bulk_return'),
    path('renew/<uuid:record_id>/', RenewBookView.as_view(), name='renew_book'),
    
    # User Borrowing Information
    path('current/', CurrentBorrowedBooksView.as_view(), name='current_borrowed'),
    path('history/', BorrowingHistoryView.as_view(), name='borrowing_history'),
    path('overdue/', OverdueBooksView.as_view(), name='overdue_books'),
    
    # Include router URLs
    path('', include(router.urls)),
]
