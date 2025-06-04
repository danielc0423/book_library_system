"""
UI views for the authentication app.
Simple HTML views for user interaction.
"""
from django.shortcuts import render
from django.views.generic import TemplateView


class SignupUIView(TemplateView):
    """
    Simple HTML view for user registration.
    """
    template_name = 'registration/signup.html'
    
    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['title'] = 'Sign Up - Library Management System'
        return context


def signup_view(request):
    """
    Function-based view for user registration form.
    """
    return render(request, 'registration/signup.html', {
        'title': 'Sign Up - Library Management System'
    })
