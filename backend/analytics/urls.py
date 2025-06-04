"""
Analytics URLs for the Library System API.
"""
from django.urls import path
from .views import (
    UserCreditScoreView, UserDashboardView,
    BookStatisticsView, LibraryTrendsView,
    AdminDashboardView, PopularBooksReportView,
    OverdueBooksReportView, UserActivityReportView
)

app_name = 'analytics'

urlpatterns = [
    # User Analytics
    path('credit-score/', UserCreditScoreView.as_view(), name='user_credit_score'),
    path('dashboard/', UserDashboardView.as_view(), name='user_dashboard'),
    
    # Book Analytics
    path('books/statistics/', BookStatisticsView.as_view(), name='book_statistics'),
    path('trends/', LibraryTrendsView.as_view(), name='library_trends'),
    
    # Admin Analytics
    path('admin/dashboard/', AdminDashboardView.as_view(), name='admin_dashboard'),
    path('admin/reports/popular-books/', PopularBooksReportView.as_view(), name='popular_books_report'),
    path('admin/reports/overdue/', OverdueBooksReportView.as_view(), name='overdue_books_report'),
    path('admin/reports/user-activity/', UserActivityReportView.as_view(), name='user_activity_report'),
]
