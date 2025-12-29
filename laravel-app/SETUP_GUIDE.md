# Laravel Twilio Bulk Lookup - Setup Guide

This Laravel application is a conversion from the Rails version, providing phone number validation, enrichment, and business intelligence via Twilio APIs.

## 🎯 Quick Start

### 1. Prerequisites

```bash
# Required
- PHP 8.2 or higher
- Composer 2.x
- PostgreSQL 15+
- Redis 7+
- Node.js 20+ & NPM

# Optional
- Supervisor (for queue workers)
- Nginx or Apache
```

### 2. Installation

```bash
cd /home/user/twilio-bulk-lookup-master/laravel-app

# Copy environment file
cp .env.twilio-lookup .env

# Generate application key
php artisan key:generate

# Install PHP dependencies
composer install

# Install JavaScript dependencies
npm install

# Build assets
npm run build
```

### 3. Database Setup

```bash
# Create PostgreSQL database
createdb twilio_bulk_lookup_laravel

# Configure .env database settings
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=twilio_bulk_lookup_laravel
DB_USERNAME=your_username
DB_PASSWORD=your_password

# Run migrations
php artisan migrate

# (Optional) Seed with sample data
php artisan db:seed
```

### 4. Redis Setup

```bash
# Start Redis server
redis-server

# Verify connection
redis-cli ping
# Should return: PONG

# Configure .env Redis settings
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
```

### 5. Create Admin User

```bash
# Create Filament admin user
php artisan make:filament-user

# Follow prompts:
# Name: Admin User
# Email: admin@example.com
# Password: (your secure password)
```

### 6. Configure Twilio Credentials

1. Log in to admin panel: `http://localhost:8000/admin`
2. Navigate to **Twilio Credentials**
3. Click **Create**
4. Enter your Twilio Account SID and Auth Token
5. Configure data packages and API integrations
6. Save

### 7. Start Queue Workers

```bash
# Terminal 1: Default queue (main processing)
php artisan queue:work redis --queue=default --tries=3 --timeout=300

# Terminal 2: Low priority queue (metrics)
php artisan queue:work redis --queue=low_priority --tries=3 --timeout=600

# Or use Horizon (recommended for production)
php artisan horizon
```

### 8. Start Development Server

```bash
# Laravel development server
php artisan serve

# Visit: http://localhost:8000
# Admin: http://localhost:8000/admin
```

---

## 📋 Configuration

### Environment Variables

Key variables in `.env`:

```bash
# Application
APP_NAME="Twilio Bulk Lookup"
APP_URL=http://localhost:8000

# Database (PostgreSQL)
DB_CONNECTION=pgsql
DB_DATABASE=twilio_bulk_lookup_laravel

# Redis (Required)
REDIS_HOST=127.0.0.1
QUEUE_CONNECTION=redis
CACHE_STORE=redis

# Twilio (stored in DB, but can set defaults)
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token

# Error Tracking
SENTRY_LARAVEL_DSN=your_sentry_dsn

# Broadcasting (for real-time updates)
BROADCAST_CONNECTION=pusher
PUSHER_APP_KEY=your_pusher_key
```

### Feature Flags

Enable/disable features via `.env`:

```bash
ENABLE_BUSINESS_ENRICHMENT=true
ENABLE_EMAIL_ENRICHMENT=true
ENABLE_ADDRESS_ENRICHMENT=true
ENABLE_VERIZON_COVERAGE=true
ENABLE_TRUST_HUB=true
ENABLE_DUPLICATE_DETECTION=true
ENABLE_CRM_SYNC=false
ENABLE_AI_ASSISTANT=true
```

---

## 🚀 Production Deployment

### 1. Optimize Application

```bash
# Cache configuration
php artisan config:cache

# Cache routes
php artisan route:cache

# Cache views
php artisan view:cache

# Optimize autoloader
composer install --optimize-autoloader --no-dev
```

### 2. Queue Workers (Supervisor)

Create `/etc/supervisor/conf.d/laravel-worker.conf`:

```ini
[program:laravel-worker-default]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/laravel-app/artisan queue:work redis --queue=default --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=4
redirect_stderr=true
stdout_logfile=/var/log/supervisor/laravel-worker.log
stopwaitsecs=3600

[program:laravel-worker-low-priority]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/laravel-app/artisan queue:work redis --queue=low_priority --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
user=www-data
numprocs=1
```

```bash
# Reload Supervisor
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
```

### 3. Web Server Configuration

**Nginx:**

```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/laravel-app/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### 4. SSL Certificate (Let's Encrypt)

```bash
sudo certbot --nginx -d your-domain.com
```

### 5. Scheduled Tasks (Cron)

Add to crontab:

```bash
* * * * * cd /path/to/laravel-app && php artisan schedule:run >> /dev/null 2>&1
```

---

## 🔧 Usage

### Importing Contacts

1. Log in to admin panel
2. Navigate to **Contacts**
3. Click **Import** button
4. Upload CSV with `phone_number` column
5. Click **Run Bulk Lookup** to process

### API Usage

**Create Contact:**

```bash
curl -X POST http://localhost:8000/api/v1/contacts \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"raw_phone_number": "+14155551234"}'
```

**List Contacts:**

```bash
curl http://localhost:8000/api/v1/contacts \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

**Get Contact:**

```bash
curl http://localhost:8000/api/v1/contacts/1 \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### Webhooks

Configure webhook URLs in your Twilio dashboard:

```
SMS Status: https://your-domain.com/webhooks/twilio/sms_status
Voice Status: https://your-domain.com/webhooks/twilio/voice_status
Trust Hub: https://your-domain.com/webhooks/twilio/trust_hub
Generic: https://your-domain.com/webhooks/generic
```

---

## 🧪 Testing

```bash
# Run all tests
php artisan test

# Run specific test suite
php artisan test --testsuite=Feature

# Run with coverage
php artisan test --coverage
```

---

## 📊 Monitoring

### Health Checks

```bash
# Basic health check
curl http://localhost:8000/health

# Readiness probe (Kubernetes)
curl http://localhost:8000/health/ready

# Detailed health
curl http://localhost:8000/health/detailed

# Queue health
curl http://localhost:8000/health/queue
```

### Queue Monitoring

```bash
# Check queue status
php artisan queue:monitor redis:default,redis:low_priority

# View failed jobs
php artisan queue:failed

# Retry failed job
php artisan queue:retry JOB_ID

# Retry all failed jobs
php artisan queue:retry all
```

---

## 🐛 Troubleshooting

### Queue Not Processing

```bash
# Check if Redis is running
redis-cli ping

# Restart queue workers
sudo supervisorctl restart all

# Clear failed jobs
php artisan queue:flush
```

### Performance Issues

```bash
# Clear all caches
php artisan optimize:clear

# Re-cache everything
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### Database Connection Issues

```bash
# Test database connection
php artisan db:show

# Clear config cache
php artisan config:clear
```

---

## 📚 Documentation

- **Conversion Status**: See `CONVERSION_STATUS.md` for Rails→Laravel conversion details
- **Services Documentation**: See `SERVICES_CONVERSION_SUMMARY.md`
- **Filament Resources**: See `FILAMENT_CONVERSION_SUMMARY.md`
- **API Documentation**: Visit `/api/documentation` (when configured)

---

## 🔐 Security

### Best Practices

1. **Never commit `.env` file** to version control
2. **Use strong passwords** for admin users
3. **Enable HTTPS** in production (Let's Encrypt)
4. **Rotate API keys** regularly
5. **Enable Twilio signature verification** for webhooks
6. **Use rate limiting** on API endpoints
7. **Enable Sentry** for error tracking

### Security Headers

Already configured in Laravel:
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- CSRF Protection enabled
- XSS Protection enabled

---

## 📞 Support

For issues or questions:
1. Check the documentation files
2. Review Laravel logs: `storage/logs/laravel.log`
3. Check Sentry for error tracking
4. Review queue failed jobs: `php artisan queue:failed`

---

## 🎉 What's Working

✅ Database models and migrations
✅ Controllers and routes
✅ Background job processing
✅ Admin panel (Filament)
✅ API endpoints
✅ Webhook processing
✅ Health checks
✅ Error tracking
✅ Circuit breaker pattern
✅ Real-time broadcasting support

## 🚧 What Needs Completion

⏳ 14 remaining service conversions (see CONVERSION_STATUS.md)
⏳ 7 custom Filament pages (Dashboard widgets, Business Lookup, etc.)
⏳ Broadcasting setup (Pusher or Laravel WebSockets)
⏳ Test suite creation
⏳ API documentation (Scramble or L5-Swagger)

---

**Version:** 1.0.0 (Converted from Rails on 2025-12-29)
