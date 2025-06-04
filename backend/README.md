# Django Backend

This is the Django REST API backend for the Book Library System.

## 🚀 Quick Start

### 1. Clone and Navigate
```bash
git clone [repository-url]
cd book_library_system/backend
```

### 2. Set Up Python Environment

#### Option A: Using venv (Recommended)
```bash
# Create virtual environment
python -m venv .venv

# Activate virtual environment
# On Windows:
.venv\Scripts\activate
# On macOS/Linux:
source .venv/bin/activate
```

#### Option B: Using UV (Faster)
```bash
# Install UV if not already installed
pip install uv

# Create and activate environment
uv venv
source .venv/bin/activate  # macOS/Linux
# or .venv\Scripts\activate on Windows
```

### 3. Install Dependencies
```bash
# Standard installation
pip install -r requirements.txt

# Or with UV (faster)
uv pip install -r requirements.txt
```

### 4. Environment Configuration

#### Create Environment File
```bash
# Copy the example environment file
cp .env.example .env
```

#### Configure .env File
```bash
# Basic development settings
DEBUG=True
SECRET_KEY=your-secret-key-here
DATABASE_URL=sqlite:///db.sqlite3

# For Oracle Database (optional)
# DATABASE_URL=oracle://username:password@host:port/service_name

# JWT Settings
JWT_SECRET_KEY=your-jwt-secret-here
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30

# Oracle Cloud (optional for development)
# OCI_CONFIG_PROFILE=DEFAULT
# OIC_ENDPOINT=your-oic-endpoint
# ANALYTICS_ENDPOINT=your-analytics-endpoint
```

### 5. Database Setup

#### For SQLite (Default Development)
```bash
# Run database migrations
python manage.py migrate

# Create initial data (optional)
python manage.py loaddata initial_data.json
```

#### For Oracle Database (Production-like)
```bash
# Install Oracle client dependencies
pip install cx_Oracle oracledb

# Update .env with Oracle connection details
# load_fixtures
python manage.py load_fixture
# Run migrations
python manage.py migrate
```


### 6. Create Admin User
```bash
python manage.py createsuperuser
```
Enter your email, username, and password when prompted.

### 7. Start Development Server
```bash
python manage.py runserver
```

Server will start at `http://localhost:8000`

## 📚 Documentation

For complete documentation, request owner for details:

## 📁 Project Structure

```
backend/
├── manage.py                # Django management script
├── requirements.txt         # Python dependencies
├── library_system/         # Django project settings
├── authentication/         # User management app
├── books/                  # Book catalog app
├── analytics/              # Analytics and reporting
├── notifications/          # Email notifications
└── [Docker, configs, etc.]
```

For detailed instructions, check the main project documentation.