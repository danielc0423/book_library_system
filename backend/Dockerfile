# Django Book Library System - Docker Configuration

FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=library_system.settings.development

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    libaio1 \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Oracle Instant Client
RUN wget https://download.oracle.com/otn_software/linux/instantclient/instantclient-basiclite-linuxx64.zip \
    && unzip instantclient-basiclite-linuxx64.zip -d /opt/oracle \
    && rm instantclient-basiclite-linuxx64.zip \
    && echo /opt/oracle/instantclient* > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && ldconfig

# Install UV for faster package management
RUN pip install uv

# Copy requirements first for better caching
COPY requirements.txt .
RUN uv venv && . .venv/bin/activate && uv pip install -r requirements.txt

# Copy project files
COPY . .

# Create necessary directories
RUN mkdir -p logs media staticfiles

# Collect static files
RUN . .venv/bin/activate && python manage.py collectstatic --noinput || true

# Create non-root user
RUN useradd -m -u 1000 library && chown -R library:library /app
USER library

# Expose port
EXPOSE 8000

# Run the application
CMD [".venv/bin/gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--timeout", "120", "library_system.wsgi:application"]
