"""
Authentication serializers for the Library System API.
"""
from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.utils import timezone
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from drf_spectacular.utils import extend_schema_field
from .models import CustomUser
from analytics.models import UserCreditScore
from notifications.models import NotificationPreference


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Custom JWT token serializer with additional user data."""
    
    def validate(self, attrs):
        data = super().validate(attrs)
        
        # Add custom claims
        data['user_id'] = self.user.id
        data['username'] = self.user.username
        data['email'] = self.user.email
        data['user_type'] = self.user.user_type
        data['is_staff'] = self.user.is_staff
        data['is_superuser'] = self.user.is_superuser
        
        # Update last login
        self.user.last_login_date = timezone.now()
        self.user.save(update_fields=['last_login_date'])
        
        return data


class UserRegistrationSerializer(serializers.ModelSerializer):
    """Serializer for user registration."""
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True, required=True)
    email = serializers.EmailField(required=True)
    
    class Meta:
        model = CustomUser
        fields = ['username', 'email', 'password', 'password_confirm', 
                  'first_name', 'last_name', 'phone_number', 'user_type']
        extra_kwargs = {
            'first_name': {'required': True},
            'last_name': {'required': True}
        }
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password": "Password fields didn't match."})
        
        if CustomUser.objects.filter(email=attrs['email']).exists():
            raise serializers.ValidationError({"email": "A user with this email already exists."})
        
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password_confirm')
        user = CustomUser.objects.create_user(**validated_data)
        
        # Create related models (use get_or_create to prevent duplicates)
        UserCreditScore.objects.get_or_create(user=user)
        NotificationPreference.objects.get_or_create(user=user)
        
        return user


class UserProfileSerializer(serializers.ModelSerializer):
    """Serializer for user profile with related data."""
    credit_score = serializers.SerializerMethodField()
    current_borrowed_books = serializers.SerializerMethodField()
    can_borrow_more = serializers.SerializerMethodField()
    borrowing_limit = serializers.SerializerMethodField()
    
    class Meta:
        model = CustomUser
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 
                  'phone_number', 'user_type', 'max_books_allowed', 
                  'registration_date', 'last_login_date', 'email_verified',
                  'phone_verified', 'credit_score', 'current_borrowed_books',
                  'can_borrow_more', 'borrowing_limit', 'is_active']
        read_only_fields = ['id', 'username', 'registration_date', 'last_login_date',
                           'credit_score', 'current_borrowed_books', 'can_borrow_more',
                           'borrowing_limit']
    
    @extend_schema_field(serializers.FloatField)
    def get_credit_score(self, obj) -> float:
        try:
            return float(obj.credit_score.credit_score)
        except:
            return 750.0
    
    @extend_schema_field(serializers.IntegerField)
    def get_current_borrowed_books(self, obj) -> int:
        return obj.borrowing_records.filter(status='borrowed').count()
    
    @extend_schema_field(serializers.BooleanField)
    def get_can_borrow_more(self, obj) -> bool:
        return obj.can_borrow_more_books()
    
    @extend_schema_field(serializers.IntegerField)
    def get_borrowing_limit(self, obj) -> int:
        return obj.get_borrowing_limit()


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating user profile."""
    class Meta:
        model = CustomUser
        fields = ['first_name', 'last_name', 'phone_number', 'backup_email']
        
    def validate_phone_number(self, value):
        if value and len(value) < 10:
            raise serializers.ValidationError("Phone number must be at least 10 digits.")
        return value


class ChangePasswordSerializer(serializers.Serializer):
    """Serializer for password change."""
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])
    new_password_confirm = serializers.CharField(required=True)
    
    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({"new_password": "Password fields didn't match."})
        return attrs
    
    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("Old password is not correct.")
        return value
    
    def save(self):
        user = self.context['request'].user
        user.set_password(self.validated_data['new_password'])
        user.save()
        return user


class PasswordResetRequestSerializer(serializers.Serializer):
    """Serializer for password reset request."""
    email = serializers.EmailField(required=True)
    
    def validate_email(self, value):
        if not CustomUser.objects.filter(email=value).exists():
            # Don't reveal whether a user exists
            pass
        return value


class PasswordResetConfirmSerializer(serializers.Serializer):
    """Serializer for password reset confirmation."""
    token = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])
    new_password_confirm = serializers.CharField(required=True)
    
    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({"new_password": "Password fields didn't match."})
        return attrs


class UserListSerializer(serializers.ModelSerializer):
    """Serializer for user listings (admin only)."""
    credit_score = serializers.SerializerMethodField()
    active_borrows = serializers.SerializerMethodField()
    
    class Meta:
        model = CustomUser
        fields = ['id', 'username', 'email', 'first_name', 'last_name',
                  'user_type', 'credit_score', 'active_borrows', 'is_active',
                  'registration_date', 'last_login_date']
    
    @extend_schema_field(serializers.FloatField)
    def get_credit_score(self, obj) -> float:
        try:
            return float(obj.credit_score.credit_score)
        except:
            return 750.0
    
    @extend_schema_field(serializers.IntegerField)
    def get_active_borrows(self, obj) -> int:
        return obj.borrowing_records.filter(status='borrowed').count()
