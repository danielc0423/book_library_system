"""
Utility functions for the library system.
"""
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status
import logging

logger = logging.getLogger(__name__)


def custom_exception_handler(exc, context):
    """
    Custom exception handler that adds additional error information.
    """
    # Call REST framework's default exception handler first
    response = exception_handler(exc, context)

    if response is not None:
        # Add custom error format
        custom_response_data = {
            'error': True,
            'message': 'An error occurred',
            'details': response.data,
            'status_code': response.status_code
        }
        
        # Log the error
        logger.error(
            f"API Error: {exc.__class__.__name__} - {str(exc)}",
            extra={
                'status_code': response.status_code,
                'request_path': context['request'].path if 'request' in context else None,
                'user': context['request'].user.id if 'request' in context and hasattr(context['request'].user, 'id') else None
            }
        )
        
        response.data = custom_response_data

    return response


def calculate_late_fee(days_overdue, fee_per_day=0.50):
    """
    Calculate late fee based on days overdue.
    
    Args:
        days_overdue (int): Number of days the book is overdue
        fee_per_day (float): Fee per day (default: $0.50)
    
    Returns:
        float: Total late fee
    """
    if days_overdue <= 0:
        return 0.0
    
    # Cap the maximum fee at 30 days
    days_to_charge = min(days_overdue, 30)
    return round(days_to_charge * fee_per_day, 2)


def generate_borrow_receipt_number():
    """
    Generate a unique receipt number for borrowing transactions.
    
    Returns:
        str: Unique receipt number (e.g., BR-2025-000001)
    """
    from datetime import datetime
    import random
    
    year = datetime.now().year
    random_num = random.randint(100000, 999999)
    return f"BR-{year}-{random_num}"


def validate_isbn(isbn):
    """
    Validate ISBN-10 or ISBN-13 format.
    
    Args:
        isbn (str): ISBN to validate
    
    Returns:
        bool: True if valid, False otherwise
    """
    # Remove hyphens and spaces
    isbn = isbn.replace('-', '').replace(' ', '')
    
    # Check ISBN-10
    if len(isbn) == 10:
        if not isbn[:-1].isdigit():
            return False
        
        total = sum((i + 1) * int(digit) for i, digit in enumerate(isbn[:-1]))
        check_digit = isbn[-1]
        
        if check_digit == 'X':
            total += 10 * 10
        elif check_digit.isdigit():
            total += 10 * int(check_digit)
        else:
            return False
            
        return total % 11 == 0
    
    # Check ISBN-13
    elif len(isbn) == 13:
        if not isbn.isdigit():
            return False
            
        total = sum((1 if i % 2 == 0 else 3) * int(digit) for i, digit in enumerate(isbn[:-1]))
        check_digit = int(isbn[-1])
        
        return (10 - (total % 10)) % 10 == check_digit
    
    return False


def get_user_borrowing_limit(user):
    """
    Get the borrowing limit for a user based on their type and credit score.
    
    Args:
        user: User instance
    
    Returns:
        int: Maximum number of books the user can borrow
    """
    base_limit = user.max_books_allowed or 5
    
    # Check if user has credit score
    if hasattr(user, 'usercreditscore'):
        credit_score = user.usercreditscore.credit_score
        
        # Bonus books based on credit score
        if credit_score >= 900:
            return base_limit + 5
        elif credit_score >= 800:
            return base_limit + 3
        elif credit_score >= 700:
            return base_limit + 1
        elif credit_score < 500:
            return max(1, base_limit - 2)
    
    return base_limit
