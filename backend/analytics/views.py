"""
Analytics views for the Library System API.
"""
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Count, Q, Avg, Sum, F
from django.utils import timezone
from datetime import timedelta
from drf_spectacular.utils import extend_schema, extend_schema_view
from .models import UserCreditScore, UserActivityLog, SystemAnalytics
from .serializers import (
    UserCreditScoreSerializer, UserDashboardSerializer,
    BookStatisticsSerializer, LibraryTrendsSerializer,
    AdminDashboardSerializer
)
from books.models import Book, BorrowingRecord, BookStatistics
from authentication.models import CustomUser


class UserCreditScoreView(generics.RetrieveAPIView):
    """Get user's credit score details."""
    serializer_class = UserCreditScoreSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        try:
            return self.request.user.credit_score
        except UserCreditScore.DoesNotExist:
            # Create default credit score if doesn't exist
            return UserCreditScore.objects.create(user=self.request.user)


@extend_schema_view(
    get=extend_schema(
        responses=UserDashboardSerializer,
        description="Get user dashboard data with borrowing summary and recommendations"
    )
)
class UserDashboardView(APIView):
    """Get user dashboard data."""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserDashboardSerializer
    
    def get(self, request):
        serializer = UserDashboardSerializer(
            data={},
            context={'request': request}
        )
        return Response(serializer.to_representation({}))


class BookStatisticsView(generics.ListAPIView):
    """Get book borrowing statistics."""
    serializer_class = BookStatisticsSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        queryset = BookStatistics.objects.select_related('book')
        
        # Filter by category if provided
        category_id = self.request.query_params.get('category')
        if category_id:
            queryset = queryset.filter(book__category_id=category_id)
        
        # Filter by date range if provided
        days = self.request.query_params.get('days')
        if days:
            try:
                days = int(days)
                start_date = timezone.now().date() - timedelta(days=days)
                queryset = queryset.filter(last_borrowed_date__gte=start_date)
            except ValueError:
                pass
        
        # Order by popularity by default
        ordering = self.request.query_params.get('ordering', '-popularity_score')
        return queryset.order_by(ordering)


@extend_schema_view(
    get=extend_schema(
        responses=LibraryTrendsSerializer,
        description="Get library usage trends and analytics for specified period"
    )
)
class LibraryTrendsView(APIView):
    """Get library usage trends and analytics."""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = LibraryTrendsSerializer
    
    def get(self, request):
        period = request.query_params.get('period', 'month')
        serializer = LibraryTrendsSerializer(data={'period': period})
        serializer.is_valid(raise_exception=True)
        return Response(serializer.to_representation({}))


@extend_schema_view(
    get=extend_schema(
        responses=AdminDashboardSerializer,
        description="Get admin dashboard data with system overview and alerts"
    )
)
class AdminDashboardView(APIView):
    """Get admin dashboard data."""
    permission_classes = [permissions.IsAdminUser]
    serializer_class = AdminDashboardSerializer
    
    def get(self, request):
        serializer = AdminDashboardSerializer(
            data={},
            context={'request': request}
        )
        return Response(serializer.to_representation({}))


@extend_schema_view(
    get=extend_schema(
        description="Generate popular books report with borrowing statistics",
        responses={
            200: {
                'type': 'object',
                'properties': {
                    'report_period': {'type': 'object'},
                    'popular_books': {'type': 'array'},
                    'category_distribution': {'type': 'array'},
                    'generated_at': {'type': 'string', 'format': 'date-time'}
                }
            }
        }
    )
)
class PopularBooksReportView(APIView):
    """Generate popular books report (admin only)."""
    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request):
        # Get parameters
        days = int(request.query_params.get('days', 30))
        limit = int(request.query_params.get('limit', 20))
        
        start_date = timezone.now().date() - timedelta(days=days)
        
        # Get most borrowed books
        popular_books = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date
        ).values(
            'book__id', 'book__title', 'book__author', 
            'book__isbn', 'book__category__name'
        ).annotate(
            borrow_count=Count('id'),
            unique_users=Count('user', distinct=True),
            avg_duration=Avg(
                F('return_date') - F('borrow_date'),
                filter=Q(return_date__isnull=False)
            )
        ).order_by('-borrow_count')[:limit]
        
        # Get category distribution
        category_stats = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date
        ).values(
            'book__category__name'
        ).annotate(
            count=Count('id')
        ).order_by('-count')
        
        return Response({
            'report_period': {
                'start_date': start_date,
                'end_date': timezone.now().date(),
                'days': days
            },
            'popular_books': list(popular_books),
            'category_distribution': list(category_stats),
            'generated_at': timezone.now()
        })


@extend_schema_view(
    get=extend_schema(
        description="Generate overdue books report with late fees and user details",
        responses={
            200: {
                'type': 'object',
                'properties': {
                    'summary': {'type': 'object'},
                    'overdue_by_category': {'type': 'object'},
                    'repeat_offenders': {'type': 'array'},
                    'generated_at': {'type': 'string', 'format': 'date-time'}
                }
            }
        }
    )
)
class OverdueBooksReportView(APIView):
    """Generate overdue books report (admin only)."""
    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request):
        # Get all overdue records
        overdue_records = BorrowingRecord.objects.filter(
            status='borrowed',
            due_date__lt=timezone.now().date()
        ).select_related('user', 'book').order_by('due_date')
        
        # Group by days overdue
        overdue_summary = {
            '1-7_days': [],
            '8-14_days': [],
            '15-30_days': [],
            'over_30_days': []
        }
        
        total_late_fees = 0
        
        for record in overdue_records:
            days_overdue = (timezone.now().date() - record.due_date).days
            late_fee = record.calculate_late_fee()
            total_late_fees += late_fee
            
            record_data = {
                'record_id': record.id,
                'user': {
                    'id': record.user.id,
                    'username': record.user.username,
                    'email': record.user.email,
                    'phone': record.user.phone_number
                },
                'book': {
                    'id': record.book.id,
                    'title': record.book.title,
                    'isbn': record.book.isbn
                },
                'borrow_date': record.borrow_date,
                'due_date': record.due_date,
                'days_overdue': days_overdue,
                'late_fee': late_fee,
                'reminder_sent': record.reminder_sent
            }
            
            if days_overdue <= 7:
                overdue_summary['1-7_days'].append(record_data)
            elif days_overdue <= 14:
                overdue_summary['8-14_days'].append(record_data)
            elif days_overdue <= 30:
                overdue_summary['15-30_days'].append(record_data)
            else:
                overdue_summary['over_30_days'].append(record_data)
        
        # Get users with most overdue books
        repeat_offenders = BorrowingRecord.objects.filter(
            status='borrowed',
            due_date__lt=timezone.now().date()
        ).values(
            'user__id', 'user__username', 'user__email'
        ).annotate(
            overdue_count=Count('id'),
            total_days_overdue=Sum(
                timezone.now().date() - F('due_date')
            )
        ).order_by('-overdue_count')[:10]
        
        return Response({
            'summary': {
                'total_overdue': overdue_records.count(),
                'total_late_fees': total_late_fees,
                '1-7_days': len(overdue_summary['1-7_days']),
                '8-14_days': len(overdue_summary['8-14_days']),
                '15-30_days': len(overdue_summary['15-30_days']),
                'over_30_days': len(overdue_summary['over_30_days'])
            },
            'overdue_by_category': overdue_summary,
            'repeat_offenders': list(repeat_offenders),
            'generated_at': timezone.now()
        })


@extend_schema_view(
    get=extend_schema(
        description="Generate user activity report with borrowing patterns and statistics",
        responses={
            200: {
                'type': 'object',
                'properties': {
                    'report_period': {'type': 'object'},
                    'user_summary': {'type': 'object'},
                    'user_type_distribution': {'type': 'array'},
                    'borrowing_by_user_type': {'type': 'array'},
                    'top_borrowers': {'type': 'array'},
                    'generated_at': {'type': 'string', 'format': 'date-time'}
                }
            }
        }
    )
)
class UserActivityReportView(APIView):
    """Generate user activity report (admin only)."""
    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request):
        days = int(request.query_params.get('days', 30))
        start_date = timezone.now().date() - timedelta(days=days)
        
        # Get new users
        new_users = CustomUser.objects.filter(
            registration_date__gte=start_date
        ).count()
        
        # Get active users
        active_users = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date
        ).values('user').distinct().count()
        
        # Get user type distribution
        user_type_stats = CustomUser.objects.values('user_type').annotate(
            count=Count('id'),
            active_count=Count(
                'borrowed_books',
                filter=Q(borrowed_books__borrow_date__gte=start_date),
                distinct=True
            )
        )
        
        # Get borrowing activity by user type
        borrowing_by_type = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date
        ).values('user__user_type').annotate(
            total_borrows=Count('id'),
            unique_books=Count('book', distinct=True),
            avg_duration=Avg(
                F('return_date') - F('borrow_date'),
                filter=Q(return_date__isnull=False)
            )
        )
        
        # Get top users
        top_borrowers = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date
        ).values(
            'user__id', 'user__username', 'user__email', 'user__user_type'
        ).annotate(
            borrow_count=Count('id'),
            on_time_returns=Count('id', filter=Q(
                return_date__isnull=False,
                return_date__lte=F('due_date')
            )),
            late_returns=Count('id', filter=Q(
                return_date__isnull=False,
                return_date__gt=F('due_date')
            ))
        ).order_by('-borrow_count')[:20]
        
        return Response({
            'report_period': {
                'start_date': start_date,
                'end_date': timezone.now().date(),
                'days': days
            },
            'user_summary': {
                'new_users': new_users,
                'active_users': active_users,
                'total_users': CustomUser.objects.filter(is_active=True).count()
            },
            'user_type_distribution': list(user_type_stats),
            'borrowing_by_user_type': list(borrowing_by_type),
            'top_borrowers': list(top_borrowers),
            'generated_at': timezone.now()
        })
