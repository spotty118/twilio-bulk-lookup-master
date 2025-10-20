# Setup Guide - Contact Management Enhancements

This guide covers setting up the new features: dynamic column management, enhanced editing, and Verizon probability scoring.

## Prerequisites

- Ruby 3.x
- Rails 7.2
- PostgreSQL
- Node.js and npm

## Installation Steps

### 1. Install Dependencies

```bash
# Install Ruby gems
bundle install

# Install JavaScript packages
npm install
```

### 2. Run Database Migrations

```bash
rails db:migrate
```

This creates:
- `verizon_5g_probability` and `verizon_lte_probability` fields on contacts
- `admin_user_column_preferences` table for per-user column settings

### 3. Configure OpenCellID API Key

The app uses OpenCellID to fetch nearby cell towers for probability calculation.

1. Register for free at: https://opencellid.org/
2. Generate an API key (Free tier: 1000 requests/day)
3. Add to your `.env` file:

```env
OPENCELLID_API_KEY=your_actual_api_key_here
```

### 4. Add SortableJS for Drag-and-Drop

Add this script tag to the `<head>` section of your ActiveAdmin layout:

```html
<script src="https://cdn.jsdelivr.net/npm/sortablejs@1.15.0/Sortable.min.js"></script>
```

Or install via npm and include in your build pipeline:

```bash
npm install sortablejs@1.15.0
```

### 5. Precompile Assets

```bash
rails assets:precompile
```

### 6. Restart Your Rails Server

```bash
rails server
```

## Feature Overview

### 1. Dynamic Column Management

**Access Points:**
- Click "Customize Columns" button above contacts table
- Navigate to `/admin/contacts/column_settings`

**Capabilities:**
- Hide/show any column via checkboxes
- Rename column labels
- Drag to reorder columns (⋮⋮ handle)
- Reset to defaults
- Settings saved per admin user

### 2. Enhanced Contact Editing

**All fields are now editable**, including:
- Basic info (phone, status)
- Carrier information (MCC, MNC, device type)
- Business data (name, industry, employee range)
- Email information
- Verizon coverage fields (availability booleans, probability scores)
- Quality scores

**Warning:** Fields marked with ⚠️ are auto-calculated and may be overwritten by background jobs.

### 3. Verizon Probability Scoring

**Automatic Calculation:**
- Triggered after Verizon coverage check completes
- Runs as background job if contact has latitude/longitude coordinates
- Calculates probability (0-100%) for both 5G and LTE

**Display:**
- Enable columns via "Customize Columns"
- Shows as: "75% High" (percentage + colored badge)
  - High (green): 70-100%
  - Medium (yellow): 30-69%
  - Low (red): 0-29%

**How it Works:**
1. Fetches nearby Verizon cell towers from OpenCellID
2. Calculates distance to nearest towers
3. Estimates coverage radius based on tower density
4. Computes probability based on distance vs coverage radius

## Public Verizon APIs Used

### 1. Verizon Serviceability API (No Auth Required)

**Endpoint:** `https://www.verizon.com/sales/nextgen/apigateway/v1/serviceability/home`

**Purpose:** Check home internet availability by address

**Used In:** `app/services/verizon_coverage_service.rb` (lines 80-128)

**Request Format:**
```ruby
POST https://www.verizon.com/sales/nextgen/apigateway/v1/serviceability/home
Content-Type: application/json

{
  "address": {
    "addressLine1": "123 Main St",
    "city": "New York",
    "state": "NY",
    "zipCode": "10001"
  }
}
```

**Response:** Returns availability for 5G Home, LTE Home, and Fios products

**Note:** This is a public endpoint that powers Verizon's address checker. No API key needed.

### 2. FCC Broadband Map API (Fallback)

**Endpoint:** `https://broadbandmap.fcc.gov/api`

**Purpose:** Get broadband provider availability by coordinates

**Used In:** `app/services/verizon_coverage_service.rb` (lines 156-200)

**No authentication required**

### 3. OpenCellID API (Requires Free API Key)

**Endpoint:** `https://opencellid.org/cell/getInArea`

**Purpose:** Get nearby cell towers for probability calculation

**Used In:** `app/services/open_cell_id_service.rb`

**Free Tier:** 1000 requests/day

## Troubleshooting

### JavaScript not working?

1. Verify SortableJS is loaded:
   - Open browser console on column settings page
   - Type: `typeof Sortable`
   - Should return: `"function"`

2. Check asset pipeline compiled the file:
   ```bash
   ls public/assets/column_settings-*.js
   ```

### Probability calculation not working?

1. Check OpenCellID API key is set:
   ```bash
   rails console
   > ENV['OPENCELLID_API_KEY']
   ```

2. Check logs for errors:
   ```bash
   tail -f log/development.log | grep "OpenCellID\|VerizonProbability"
   ```

3. Verify contact has coordinates:
   ```ruby
   Contact.find(id).latitude.present?
   ```

### Column preferences not saving?

1. Verify migration ran:
   ```bash
   rails db:migrate:status | grep admin_user_column_preferences
   ```

2. Check you're logged in as admin user

3. Check browser console for errors during save

## Manual Testing Checklist

- [ ] Can customize columns (hide/show/rename/reorder)
- [ ] Column preferences persist after logout/login
- [ ] Different admin users have separate preferences
- [ ] Reset to defaults works
- [ ] Can edit all contact fields in edit form
- [ ] Verizon probability columns appear when enabled
- [ ] Probability badges show correct colors
- [ ] Probability calculation runs after coverage check

## Next Steps

1. Run through manual testing checklist
2. Configure production OpenCellID API key
3. Monitor API usage (1000 free requests/day limit)
4. Consider upgrading OpenCellID plan if needed

## Support

For issues:
- Check logs: `tail -f log/development.log`
- Rails console debugging: `rails console`
- Background job status: Check Sidekiq/ActiveJob dashboard
