# Verizon Public APIs - No Authentication Required

This document details public Verizon APIs that can be used without API keys.

## 1. Verizon Serviceability API ✅ **IMPLEMENTED**

### Overview
Public endpoint used by Verizon's website to check home internet availability.

### Endpoint
```
POST https://www.verizon.com/sales/nextgen/apigateway/v1/serviceability/home
```

### Authentication
**None required** - This is the same endpoint Verizon's public website uses.

### Implementation
**File:** `app/services/verizon_coverage_service.rb` (lines 80-128)

### Request Format
```json
{
  "address": {
    "addressLine1": "123 Main Street",
    "city": "New York",
    "state": "NY",
    "zipCode": "10001"
  }
}
```

### Response Format
```json
{
  "serviceability": {
    "products": [
      {
        "name": "Fios Internet",
        "available": true,
        "speeds": {
          "download": "940 Mbps",
          "upload": "880 Mbps"
        }
      },
      {
        "name": "5G Home Internet",
        "available": true,
        "speeds": {
          "download": "300 Mbps",
          "upload": "50 Mbps"
        }
      },
      {
        "name": "LTE Home Internet",
        "available": false
      }
    ]
  }
}
```

### What We Extract
- **Fios Availability**: Boolean
- **5G Home Availability**: Boolean
- **LTE Home Availability**: Boolean
- **Download Speeds**: Range (e.g., "300-940 Mbps")
- **Upload Speeds**: Range (e.g., "50-880 Mbps")

### Usage Example
```ruby
service = VerizonCoverageService.new(contact)
service.check_coverage
# Updates contact with verizon_5g_home_available, verizon_lte_home_available, etc.
```

### Rate Limiting
- No official rate limits documented
- Appears to be generous (website uses it for every address check)
- Recommended: Throttle requests to ~10/second to be respectful

### Reliability
- **High** - This is production infrastructure for Verizon's website
- Occasional timeouts (handled with 10s timeout + fallback methods)

---

## 2. Verizon Coverage Map (Web Scraping Alternative)

### Overview
Verizon's public coverage map page can be parsed for coverage data.

### Endpoint
```
GET https://www.verizon.com/coverage-map/
```

### Authentication
None required (public website)

### Implementation Status
❌ **NOT IMPLEMENTED** (could be added as fallback)

### How It Works
1. Load coverage map page with address parameter
2. Parse HTML/JavaScript for coverage indicators
3. Extract 5G/LTE availability

### Pros
- No authentication needed
- Shows real network coverage

### Cons
- Web scraping is fragile (breaks when HTML changes)
- Slower than API calls
- May violate terms of service

### Recommendation
**Use only as last resort fallback** after API and FCC methods fail.

---

## 3. FCC Broadband Map API ✅ **IMPLEMENTED**

### Overview
Federal Communications Commission's public API for broadband provider data.

### Endpoint
```
GET https://broadbandmap.fcc.gov/api/public/map/basic/area/[lat]/[lon]/[radius]
```

### Authentication
**None required** - Public government API

### Implementation
**File:** `app/services/verizon_coverage_service.rb` (lines 156-200)

### Request Format
```
GET https://broadbandmap.fcc.gov/api/public/map/basic/area/40.7128/-74.0060/0.5
```
Parameters:
- `lat`: Latitude (e.g., 40.7128)
- `lon`: Longitude (e.g., -74.0060)
- `radius`: Search radius in miles (e.g., 0.5)

### Response Format
```json
{
  "status": "OK",
  "results": [
    {
      "provider": "Verizon",
      "technology": "Fixed Wireless",
      "maxDownload": "300",
      "maxUpload": "50"
    }
  ]
}
```

### What We Extract
- Verizon wireless broadband availability
- Technology type (helps identify 5G vs LTE)
- Speed capabilities

### Usage
Used as **fallback** when Verizon API fails or returns no data.

### Rate Limiting
- No official limits
- Government API, generally stable

### Reliability
- **Medium** - Data can be outdated (updated quarterly)
- Not as accurate as Verizon's own API

---

## 4. OpenCellID API ⚠️ **REQUIRES FREE API KEY**

### Overview
Cell tower location database for calculating coverage probability.

### Endpoint
```
GET https://opencellid.org/cell/getInArea
```

### Authentication
**API Key Required** (Free tier available)

### Registration
1. Visit https://opencellid.org/
2. Create free account
3. Generate API key
4. Add to `.env`: `OPENCELLID_API_KEY=your_key`

### Free Tier Limits
- **1,000 requests per day**
- Sufficient for most use cases
- Paid plans available for higher volume

### Implementation
**File:** `app/services/open_cell_id_service.rb`

### Request Format
```
GET https://opencellid.org/cell/getInArea?key=API_KEY&lat=40.7128&lon=-74.0060&radius=10000&format=json&radio=NR
```

Parameters:
- `key`: Your API key
- `lat`: Latitude
- `lon`: Longitude
- `radius`: Radius in meters (10000 = 10km)
- `format`: json
- `radio`: NR (5G), LTE (4G), or all

### Response Format
```json
{
  "cells": [
    {
      "radio": "NR",
      "mcc": 310,
      "mnc": 13,
      "lat": 40.7130,
      "lon": -74.0055,
      "range": 2000
    }
  ]
}
```

### What We Calculate
- Distance to nearest Verizon towers (mnc=13)
- Coverage probability based on tower proximity
- Separate scores for 5G and LTE

### Why It's Worth The API Key
This is the **most accurate** method for probability calculation:
- Pinpoint tower locations
- Real signal coverage estimates
- Distinguishes between 5G and LTE

---

## 5. ThingSpace APIs ❌ **REQUIRES AUTHENTICATION**

### Overview
Verizon's IoT platform with network performance APIs.

### Endpoints
- Fixed Wireless Qualification API
- Wireless Network Performance API
- Device Experience API

### Authentication
Requires Verizon Business account + OAuth tokens

### Why Not Used
- Requires business partnership with Verizon
- OAuth setup complexity
- Designed for IoT devices, not consumer internet
- Overkill for our use case

---

## Summary & Recommendations

### Currently Implemented (Priority Order)

1. **Verizon Serviceability API** ✅ (No auth, best data)
2. **OpenCellID + Probability Calculation** ✅ (Free API key, most accurate)
3. **FCC Broadband Map** ✅ (No auth, fallback)
4. **Zip Code Estimation** ✅ (No auth, last resort)

### Architecture

```
Contact with Address
        ↓
VerizonCoverageCheckJob (Background)
        ↓
VerizonCoverageService
        ↓
    ┌───────────────────┐
    ↓                   ↓                   ↓
Method 1:           Method 2:           Method 3:
Verizon API         FCC API             Zip Estimation
(Best)              (Fallback)          (Last Resort)
    ↓
Sets boolean flags (5G/LTE/Fios available)
        ↓
VerizonProbabilityCalculationJob (Background)
        ↓
VerizonProbabilityService
        ↓
OpenCellID API (gets towers)
        ↓
Calculates probability scores (0-100%)
        ↓
Updates contact record
```

### API Usage Optimization

**For 1000 contacts:**
- Verizon Serviceability: ~1000 calls (1 per contact)
- OpenCellID: ~1000 calls if all have addresses
  - Falls within free 1000/day limit
  - Schedule checks throughout the day

**Optimization Strategies:**
1. Cache results for 30 days (coverage rarely changes)
2. Batch process overnight
3. Skip recalculation if data is <7 days old
4. Fallback to boolean-based estimation if API limit reached

### Cost Analysis

| API | Authentication | Rate Limit | Cost |
|-----|---------------|------------|------|
| Verizon Serviceability | None | Unknown (generous) | **FREE** |
| FCC Broadband Map | None | None | **FREE** |
| OpenCellID | Free API Key | 1000/day | **FREE** |
| OpenCellID Paid | Paid API Key | Unlimited | $50/month |

**Recommendation:** Start with free tier. Monitor usage. Upgrade OpenCellID if needed.

### Testing the APIs

```bash
# Test Verizon API
curl -X POST https://www.verizon.com/sales/nextgen/apigateway/v1/serviceability/home \
  -H "Content-Type: application/json" \
  -d '{"address":{"addressLine1":"1 Verizon Way","city":"Basking Ridge","state":"NJ","zipCode":"07920"}}'

# Test FCC API
curl "https://broadbandmap.fcc.gov/api/public/map/basic/area/40.7128/-74.0060/0.5"

# Test OpenCellID (need API key)
curl "https://opencellid.org/cell/getInArea?key=YOUR_KEY&lat=40.7128&lon=-74.0060&radius=10000&format=json"
```

### Future Enhancements

1. **Add caching layer** for API responses (Redis)
2. **Implement retry logic** with exponential backoff
3. **Add monitoring** for API success rates
4. **Create admin dashboard** showing API usage stats
5. **Add webhook** for real-time coverage updates
