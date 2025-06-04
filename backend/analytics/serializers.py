"""
Analytics serializers for the Library System API.
"""
from rest_framework import serializers
from django.db.models import Count, Q, Avg, Sum, F
from django.db import models
from django.utils import timezone
from datetime import timedelta
from drf_spectacular.utils import extend_schema_field
from .models import UserCreditScore, UserActivityLog, SystemAnalytics
from books.models import Book, BorrowingRecord, BookStatistics
from authentication.models import CustomUser


class UserCreditScoreSerializer(serializers.ModelSerializer):
    """Serializer for user credit score details."""
    score_category = serializers.SerializerMethodField()
    borrowing_privileges = serializers.SerializerMethodField()
    score_breakdown = serializers.SerializerMethodField()
    cross_system_scores = serializers.JSONField(source='external_system_scores', read_only=True)
    
    class Meta:
        model = UserCreditScore
        fields = ['credit_score', 'on_time_returns', 'late_returns', 
                  'total_books_borrowed', 'average_return_delay', 
                  'reliability_rating', 'score_category', 'borrowing_privileges',
                  'score_breakdown', 'composite_score', 'cross_system_scores',
                  'last_calculated']
    
    @extend_schema_field(serializers.CharField)
    def get_score_category(self, obj) -> str:
        score = float(obj.credit_score)
        if score >= 900:
            return 'Excellent'
        elif score >= 800:
            return 'Very Good'
        elif score >= 700:
            return 'Good'
        elif score >= 600:
            return 'Fair'
        else:
            return 'Poor'
    
    @extend_schema_field(serializers.DictField)
    def get_borrowing_privileges(self, obj) -> dict:
        score = float(obj.credit_score)
        return {
            'max_books': obj.user.max_books_allowed,
            'loan_period_days': 30 if score >= 800 else 21 if score >= 700 else 14,
            'renewal_allowed': score >= 600,
            'max_renewals': 3 if score >= 800 else 2 if score >= 700 else 1,
            'late_fee_discount': 50 if score >= 900 else 25 if score >= 800 else 0,
            'priority_reservations': score >= 800
        }
    
    @extend_schema_field(serializers.DictField)
    def get_score_breakdown(self, obj) -> dict:
        total_transactions = obj.on_time_returns + obj.late_returns
        on_time_rate = (obj.on_time_returns / total_transactions * 100) if total_transactions > 0 else 100
        
        return {
            'on_time_rate': round(on_time_rate, 2),
            'late_rate': round(100 - on_time_rate, 2),
            'average_delay_days': float(obj.average_return_delay),
            'total_transactions': total_transactions,
            'score_factors': {
                'punctuality': 'Excellent' if on_time_rate >= 95 else 'Good' if on_time_rate >= 85 else 'Fair',
                'frequency': 'High' if total_transactions >= 50 else 'Medium' if total_transactions >= 20 else 'Low',
                'reliability': obj.reliability_rating
            }
        }


class UserDashboardSerializer(serializers.Serializer):
    """Serializer for user dashboard data."""
    user_summary = serializers.SerializerMethodField()
    borrowing_summary = serializers.SerializerMethodField()
    current_books = serializers.SerializerMethodField()
    borrowing_history = serializers.SerializerMethodField()
    recommendations = serializers.SerializerMethodField()
    
    @extend_schema_field(serializers.DictField)
    def get_user_summary(self, obj) -> dict:
        user = self.context['request'].user
        try:
            credit_score = user.credit_score.credit_score
        except:
            credit_score = 750
            
        return {
            'name': user.get_full_name(),
            'user_type': user.user_type,
            'member_since': user.registration_date,
            'credit_score': float(credit_score),
            'borrowing_limit': user.get_borrowing_limit(),
            'email_verified': user.email_verified,
            'phone_verified': user.phone_verified
        }
    
    @extend_schema_field(serializers.DictField)
    def get_borrowing_summary(self, obj) -> dict:
        user = self.context['request'].user
        records = user.borrowing_records.all()
        current_borrowed = records.filter(status='borrowed')
        
        return {
            'current_borrowed': current_borrowed.count(),
            'total_borrowed': records.count(),
            'overdue_books': current_borrowed.filter(due_date__lt=timezone.now().date()).count(),
            'books_due_soon': current_borrowed.filter(
                due_date__gte=timezone.now().date(),
                due_date__lte=timezone.now().date() + timedelta(days=3)
            ).count(),
            'total_late_fees': float(records.aggregate(Sum('late_fees'))['late_fees__sum'] or 0),
            'can_borrow_more': user.can_borrow_more_books()
        }
    
    @extend_schema_field(serializers.ListField)
    def get_current_books(self, obj) -> list:
        user = self.context['request'].user
        current_records = user.borrowing_records.filter(
            status='borrowed'
        ).select_related('book').order_by('due_date')
        
        return [{
            'record_id': record.id,
            'book_id': record.book.id,
            'title': record.book.title,
            'author': record.book.author,
            'isbn': record.book.isbn,
            'borrow_date': record.borrow_date,
            'due_date': record.due_date,
            'days_remaining': (record.due_date - timezone.now().date()).days,
            'is_overdue': record.is_overdue(),
            'can_renew': record.can_renew(),
            'renewal_count': record.renewal_count
        } for record in current_records[:10]]
    
    @extend_schema_field(serializers.ListField)
    def get_borrowing_history(self, obj) -> list:
        user = self.context['request'].user
        recent_records = user.borrowing_records.filter(
            status='returned'
        ).select_related('book').order_by('-return_date')[:10]
        
        return [{
            'book_title': record.book.title,
            'author': record.book.author,
            'borrow_date': record.borrow_date,
            'return_date': record.return_date,
            'was_late': record.late_fees > 0,
            'late_fees': float(record.late_fees)
        } for record in recent_records]
    
    @extend_schema_field(serializers.ListField)
    def get_recommendations(self, obj) -> list:
        user = self.context['request'].user
        
        # Get user's favorite categories based on borrowing history
        favorite_categories = user.borrowing_records.values(
            'book__category'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:3]
        
        category_ids = [cat['book__category'] for cat in favorite_categories]
        
        # Get popular books from favorite categories that user hasn't borrowed
        borrowed_book_ids = user.borrowing_records.values_list('book_id', flat=True)
        
        recommended_books = Book.objects.filter(
            category_id__in=category_ids,
            is_active=True,
            available_copies__gt=0
        ).exclude(
            id__in=borrowed_book_ids
        ).select_related(
            'statistics'
        ).order_by(
            '-statistics__popularity_score'
        )[:5]
        
        return [{
            'book_id': book.id,
            'title': book.title,
            'author': book.author,
            'category': book.category.name,
            'popularity_score': float(book.statistics.popularity_score) if hasattr(book, 'statistics') else 0
        } for book in recommended_books]


class BookStatisticsSerializer(serializers.ModelSerializer):
    """Serializer for book statistics."""
    book_title = serializers.CharField(source='book.title', read_only=True)
    book_author = serializers.CharField(source='book.author', read_only=True)
    availability_rate = serializers.SerializerMethodField()
    
    class Meta:
        model = BookStatistics
        fields = ['book', 'book_title', 'book_author', 'total_borrowed_count',
                  'current_borrowed_count', 'average_borrowing_duration',
                  'popularity_score', 'last_borrowed_date', 'availability_rate',
                  'last_updated']
    
    @extend_schema_field(serializers.FloatField)
    def get_availability_rate(self, obj) -> float:
        total = obj.book.total_copies
        available = obj.book.available_copies
        return round((available / total * 100) if total > 0 else 0, 2)


class LibraryTrendsSerializer(serializers.Serializer):
    """Serializer for library usage trends."""
    period = serializers.ChoiceField(choices=['week', 'month', 'quarter', 'year'], default='month')
    
    def to_representation(self, instance):
        period = self.validated_data.get('period', 'month')
        
        # Calculate date range
        end_date = timezone.now().date()
        if period == 'week':
            start_date = end_date - timedelta(days=7)
        elif period == 'month':
            start_date = end_date - timedelta(days=30)
        elif period == 'quarter':
            start_date = end_date - timedelta(days=90)
        else:  # year
            start_date = end_date - timedelta(days=365)
        
        # Get borrowing trends
        borrowing_by_day = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date,
            borrow_date__lte=end_date
        ).values('borrow_date').annotate(count=Count('id')).order_by('borrow_date')
        
        # Get popular categories
        popular_categories = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date,
            borrow_date__lte=end_date
        ).values(
            'book__category__name'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:10]
        
        # Get popular books
        popular_books = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date,
            borrow_date__lte=end_date
        ).values(
            'book__title', 'book__author'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:10]
        
        # Get user activity
        active_users = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date,
            borrow_date__lte=end_date
        ).values('user').distinct().count()
        
        # Calculate averages
        total_borrows = BorrowingRecord.objects.filter(
            borrow_date__gte=start_date,
            borrow_date__lte=end_date
        ).count()
        
        avg_duration = BorrowingRecord.objects.filter(
            return_date__isnull=False,
            borrow_date__gte=start_date,
            return_date__lte=end_date
        ).annotate(
            duration=models.F('return_date') - models.F('borrow_date')
        ).aggregate(avg=Avg('duration'))['avg']
        
        return {
            'period': period,
            'date_range': {
                'start': start_date,
                'end': end_date
            },
            'borrowing_trends': list(borrowing_by_day),
            'popular_categories': list(popular_categories),
            'popular_books': list(popular_books),
            'summary': {
                'total_borrows': total_borrows,
                'active_users': active_users,
                'average_duration_days': avg_duration.days if avg_duration else 0,
                'daily_average': round(total_borrows / ((end_date - start_date).days + 1), 2)
            }
        }


class AdminDashboardSerializer(serializers.Serializer):
    """Serializer for admin dashboard data."""
    system_overview = serializers.SerializerMethodField()
    recent_activity = serializers.SerializerMethodField()
    alerts = serializers.SerializerMethodField()
    top_statistics = serializers.SerializerMethodField()
    
    @extend_schema_field(serializers.DictField)
    def get_system_overview(self, obj) -> dict:
        total_users = CustomUser.objects.filter(is_active=True).count()
        total_books = Book.objects.filter(is_active=True).count()
        current_borrows = BorrowingRecord.objects.filter(status='borrowed').count()
        overdue_books = BorrowingRecord.objects.filter(
            status='borrowed',
            due_date__lt=timezone.now().date()
        ).count()
        
        return {
            'total_users': total_users,
            'total_books': total_books,
            'current_borrows': current_borrows,
            'overdue_books': overdue_books,
            'available_books': Book.objects.filter(available_copies__gt=0).count(),
            'new_users_today': CustomUser.objects.filter(
                registration_date=timezone.now().date()
            ).count()
        }
    
    @extend_schema_field(serializers.DictField)
    def get_recent_activity(self, obj) -> dict:
        recent_borrows = BorrowingRecord.objects.filter(
            borrow_date=timezone.now().date()
        ).select_related('user', 'book').order_by('-created_at')[:10]
        
        recent_returns = BorrowingRecord.objects.filter(
            return_date=timezone.now().date()
        ).select_related('user', 'book').order_by('-updated_at')[:10]
        
        return {
            'recent_borrows': [{
                'user': record.user.username,
                'book': record.book.title,
                'time': record.created_at
            } for record in recent_borrows],
            'recent_returns': [{
                'user': record.user.username,
                'book': record.book.title,
                'time': record.updated_at,
                'was_late': record.late_fees > 0
            } for record in recent_returns]
        }
    
    @extend_schema_field(serializers.ListField)
    def get_alerts(self, obj) -> list:
        alerts = []
        
        # Check for critically low inventory
        low_inventory = Book.objects.filter(
            available_copies__lte=2,
            is_active=True
        ).exclude(available_copies=0).count()
        
        if low_inventory > 0:
            alerts.append({
                'type': 'warning',
                'message': f'{low_inventory} books have low inventory (≤2 copies)',
                'priority': 'medium'
            })
        
        # Check for many overdue books
        overdue_count = BorrowingRecord.objects.filter(
            status='borrowed',
            due_date__lt=timezone.now().date()
        ).count()
        
        if overdue_count > 10:
            alerts.append({
                'type': 'error',
                'message': f'{overdue_count} books are overdue',
                'priority': 'high'
            })
        
        # Check for system issues
        try:
            latest_analytics = SystemAnalytics.objects.latest('date')
            if latest_analytics.date < timezone.now().date() - timedelta(days=1):
                alerts.append({
                    'type': 'warning',
                    'message': 'System analytics not updated today',
                    'priority': 'low'
                })
        except SystemAnalytics.DoesNotExist:
            pass
        
        return alerts
    
    @extend_schema_field(serializers.DictField)
    def get_top_statistics(self, obj) -> dict:
        # Most borrowed books this month
        start_of_month = timezone.now().date().replace(day=1)
        
        top_borrowed = BorrowingRecord.objects.filter(
            borrow_date__gte=start_of_month
        ).values(
            'book__title', 'book__author'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:5]
        
        # Most active users
        top_users = BorrowingRecord.objects.filter(
            borrow_date__gte=start_of_month
        ).values(
            'user__username', 'user__email'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:5]
        
        return {
            'top_borrowed_books': list(top_borrowed),
            'most_active_users': list(top_users),
            'period': f"Since {start_of_month}"
        }
