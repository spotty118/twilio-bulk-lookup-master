# 🚀 Quick Start Guide

Get Twilio Bulk Lookup running in minutes with Docker!

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed
- [Docker Compose](https://docs.docker.com/compose/install/) installed
- Twilio Account (get free trial at [twilio.com/try-twilio](https://twilio.com/try-twilio))

## Quick Setup (3 Steps)

### 1. Clone & Configure

```bash
# Clone the repository
git clone https://github.com/spotty118/twilio-bulk-lookup-master.git
cd twilio-bulk-lookup-master

# Copy environment template
cp .env.example .env
```

### 2. Add Your Twilio Credentials

Edit `.env` file and add your Twilio credentials:

```bash
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here
```

Find your credentials at: https://console.twilio.com/

### 3. Start the Application

```bash
# Using the start script (recommended)
bash start.sh

# OR manually with docker-compose
docker-compose up --build -d
```

That's it! 🎉

## Access the Application

After startup (takes 1-2 minutes for first time):

- **Admin Dashboard**: http://localhost:3002/admin
- **Main App**: http://localhost:3002
- **Sidekiq Monitor**: http://localhost:3002/sidekiq

### Default Login

```
Email:    admin@example.com
Password: password
```

⚠️ **Change the password immediately after first login!**

## What's Running?

The application starts three Docker containers:

1. **PostgreSQL** - Database (port 5432)
2. **Redis** - Background job queue (port 6379)
3. **Rails Web Server** - Main application (port 3002)
4. **Sidekiq** - Background worker for processing

## Common Commands

```bash
# View logs (all services)
docker-compose logs -f

# View web server logs only
docker-compose logs -f web

# View Sidekiq worker logs
docker-compose logs -f sidekiq

# Stop the application
docker-compose down

# Stop and remove all data
docker-compose down -v

# Restart a specific service
docker-compose restart web

# Access Rails console
docker-compose exec web bundle exec rails console

# Run database migrations
docker-compose exec web bundle exec rails db:migrate

# Reset database (⚠️ deletes all data!)
docker-compose exec web bundle exec rails db:reset
```

## Next Steps

### 1. Configure API Integrations

Navigate to **Admin → API Connectors** to set up optional data providers:

- **Business Intelligence**: Clearbit, NumVerify
- **Email Discovery**: Hunter.io, ZeroBounce
- **Address Data**: Whitepages Pro, TrueCaller
- **AI Features**: OpenAI, Anthropic Claude, Google Gemini
- **Business Search**: Google Places, Yelp
- **CRM Sync**: Salesforce, HubSpot, Pipedrive

### 2. Import Contacts

**Method A: CSV Upload**
1. Go to **Admin → Contacts**
2. Click **Import Contacts**
3. Upload CSV with column: `raw_phone_number`

Example CSV:
```csv
raw_phone_number
+14155551234
+14155555678
```

**Method B: Business Lookup**
1. Go to **Admin → Business Lookup**
2. Enter zipcodes (e.g., 90210, 10001)
3. System finds and imports businesses automatically

### 3. Run Enrichment

1. Navigate to **Admin → Dashboard**
2. Click **Run Lookup** button
3. Monitor progress in **Sidekiq Monitor**

### 4. Export Results

1. Go to **Admin → Contacts**
2. Use filters to select contacts
3. Click **Download** and choose format (CSV/TSV/Excel)

## Troubleshooting

### Application Won't Start

```bash
# Check if ports are already in use
lsof -i :3002  # Web server port
lsof -i :5432  # PostgreSQL port
lsof -i :6379  # Redis port

# View detailed error logs
docker-compose logs web
```

### Database Connection Issues

```bash
# Restart database container
docker-compose restart db

# Check database status
docker-compose ps db
```

### Sidekiq Not Processing Jobs

```bash
# Check Sidekiq logs
docker-compose logs sidekiq

# Restart Sidekiq worker
docker-compose restart sidekiq
```

### Reset Everything

```bash
# Stop all containers and remove volumes
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Start fresh
docker-compose up --build -d
```

## Production Deployment

### Heroku (Easiest)

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

Or manually:

```bash
heroku create your-app-name
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini

heroku config:set TWILIO_ACCOUNT_SID='ACxxxx...'
heroku config:set TWILIO_AUTH_TOKEN='your_token'

git push heroku main
heroku run rails db:migrate db:seed
```

### Docker on VPS

```bash
# Update .env with production values
RAILS_ENV=production
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# Build for production
docker-compose -f docker-compose.prod.yml up -d

# Set up SSL with Caddy or nginx
```

## Getting Help

- 📖 **Full Documentation**: See [README.md](README.md)
- 🔧 **API Configuration**: See [API_CONFIGURATION_GUIDE.md](API_CONFIGURATION_GUIDE.md)
- 🐛 **Issues**: [GitHub Issues](https://github.com/spotty118/twilio-bulk-lookup-master/issues)
- 💬 **Twilio Support**: [Twilio Help Center](https://support.twilio.com/)

## Features Overview

✅ **Bulk Phone Lookup** - Process thousands of numbers
✅ **14+ API Integrations** - Business data, emails, addresses
✅ **AI Assistant** - Natural language contact search
✅ **CRM Sync** - Salesforce, HubSpot, Pipedrive
✅ **SMS & Voice** - Automated outreach campaigns
✅ **Trust Hub** - Business verification
✅ **Quality Scoring** - Automated data quality metrics
✅ **Duplicate Detection** - Smart deduplication
✅ **Background Jobs** - Async processing with Sidekiq
✅ **Admin Dashboard** - Comprehensive management interface

## Security Notes

⚠️ **Important Security Practices:**

1. Change default admin password immediately
2. Use strong, unique passwords
3. Never commit credentials to Git
4. Use environment variables for sensitive data
5. Enable HTTPS in production
6. Regularly update dependencies
7. Monitor access logs
8. Rotate API keys periodically

## Support This Project

Found this useful? ⭐ Star the repo on [GitHub](https://github.com/spotty118/twilio-bulk-lookup-master)!

---

**License**: See [LICENSE](LICENSE)  
**Disclaimer**: Not officially supported by Twilio. Use at your own risk.
