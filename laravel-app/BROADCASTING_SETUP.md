# Broadcasting Setup Guide

This document explains how to set up real-time broadcasting for the Twilio Bulk Lookup Laravel application.

## Overview

The application uses Laravel Broadcasting to provide real-time updates for:
- **Contact Updates**: Live table refresh when contacts are processed
- **Dashboard Stats**: Real-time stat card updates

## Events Created

### 1. ContactUpdated
- **File**: `app/Events/ContactUpdated.php`
- **Channel**: `contacts` (public channel)
- **Event Name**: `contact.updated`
- **Data**: Contact ID, phone numbers, status, business name, email
- **Trigger**: When a contact is processed or updated

### 2. DashboardStatsUpdated
- **File**: `app/Events/DashboardStatsUpdated.php`
- **Channel**: `dashboard` (public channel)
- **Event Name**: `dashboard.stats.updated`
- **Data**: Total, pending, processing, completed, failed counts
- **Trigger**: When contact stats change

## Broadcasting Options

You have **3 options** for broadcasting:

### Option 1: Pusher (Recommended for Production)

**Pros:**
- Fully managed service (no infrastructure needed)
- Auto-scaling
- Global CDN
- Free tier: 200k messages/day

**Setup:**

```bash
# Install Pusher PHP SDK
composer require pusher/pusher-php-server

# Install JavaScript libraries
npm install --save-dev laravel-echo pusher-js
```

**Configure `.env`:**
```env
BROADCAST_CONNECTION=pusher

PUSHER_APP_ID=your_app_id
PUSHER_APP_KEY=your_app_key
PUSHER_APP_SECRET=your_app_secret
PUSHER_APP_CLUSTER=mt1
PUSHER_SCHEME=https
```

**Get Pusher Credentials:**
1. Sign up at https://pusher.com
2. Create a new app
3. Copy credentials to `.env`

---

### Option 2: Laravel WebSockets (Self-Hosted)

**Pros:**
- Free and open source
- No external dependencies
- Full control

**Cons:**
- Requires WebSocket server management
- Higher server resource usage

**Setup:**

```bash
# Install Laravel WebSockets
composer require beyondcode/laravel-websockets

# Publish configuration
php artisan vendor:publish --provider="BeyondCode\LaravelWebSockets\WebSocketsServiceProvider" --tag="migrations"
php artisan migrate

php artisan vendor:publish --provider="BeyondCode\LaravelWebSockets\WebSocketsServiceProvider" --tag="config"

# Install JavaScript libraries
npm install --save-dev laravel-echo pusher-js
```

**Configure `.env`:**
```env
BROADCAST_CONNECTION=pusher

PUSHER_APP_ID=local
PUSHER_APP_KEY=local
PUSHER_APP_SECRET=local
PUSHER_HOST=127.0.0.1
PUSHER_PORT=6001
PUSHER_SCHEME=http
PUSHER_APP_CLUSTER=mt1
```

**Start WebSocket Server:**
```bash
php artisan websockets:serve
```

**Dashboard:**
Visit http://localhost:8000/laravel-websockets to monitor connections.

---

### Option 3: Redis Broadcasting (Simple, No Pusher)

**Pros:**
- Uses existing Redis infrastructure
- No external service needed
- Simple setup

**Cons:**
- Requires custom frontend polling or Socket.io setup
- Less efficient than WebSockets

**Setup:**

```bash
# Already have predis/predis installed
```

**Configure `.env`:**
```env
BROADCAST_CONNECTION=redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
```

**Note:** With Redis broadcasting, you'll need to poll for updates or implement Socket.io separately.

---

## Frontend Integration

### Update `resources/js/bootstrap.js`

```javascript
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'pusher',
    key: import.meta.env.VITE_PUSHER_APP_KEY,
    cluster: import.meta.env.VITE_PUSHER_APP_CLUSTER ?? 'mt1',
    wsHost: import.meta.env.VITE_PUSHER_HOST ?? `ws-${import.meta.env.VITE_PUSHER_APP_CLUSTER}.pusher.com`,
    wsPort: import.meta.env.VITE_PUSHER_PORT ?? 80,
    wssPort: import.meta.env.VITE_PUSHER_PORT ?? 443,
    forceTLS: (import.meta.env.VITE_PUSHER_SCHEME ?? 'https') === 'https',
    enabledTransports: ['ws', 'wss'],
});
```

### Update `.env` (Vite variables)

```env
VITE_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
VITE_PUSHER_HOST="${PUSHER_HOST}"
VITE_PUSHER_PORT="${PUSHER_PORT}"
VITE_PUSHER_SCHEME="${PUSHER_SCHEME}"
VITE_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"
```

### Build Assets

```bash
npm run build
```

---

## Listening to Events

### In Filament Admin Panel

Create a Livewire component or add to existing views:

```javascript
// Listen to contact updates
window.Echo.channel('contacts')
    .listen('.contact.updated', (e) => {
        console.log('Contact updated:', e);
        // Refresh Filament table
        Livewire.dispatch('refreshComponent');
    });

// Listen to dashboard stats
window.Echo.channel('dashboard')
    .listen('.dashboard.stats.updated', (e) => {
        console.log('Dashboard stats:', e);
        // Update stat widgets
        Livewire.dispatch('updateStats', e);
    });
```

### In Custom Blade Views

```html
@push('scripts')
<script>
    Echo.channel('contacts')
        .listen('.contact.updated', (e) => {
            // Update UI
            updateContactRow(e.id, e);
        });
</script>
@endpush
```

---

## Triggering Events

### From Jobs

```php
use App\Events\ContactUpdated;
use App\Events\DashboardStatsUpdated;

// In ContactBroadcastJob
public function handle()
{
    $contact = Contact::find($this->contactId);

    broadcast(new ContactUpdated($contact));
}

// In DashboardBroadcastJob
public function handle()
{
    $stats = [
        'total' => Contact::count(),
        'pending' => Contact::pending()->count(),
        'processing' => Contact::processing()->count(),
        'completed' => Contact::completed()->count(),
        'failed' => Contact::failed()->count(),
    ];

    broadcast(new DashboardStatsUpdated($stats));
}
```

### From Controllers/Services

```php
use App\Events\ContactUpdated;

// After updating a contact
$contact->update(['status' => 'completed']);
ContactUpdated::dispatch($contact);
```

---

## Testing Broadcasting

### Test with Tinker

```bash
php artisan tinker

>>> use App\Events\ContactUpdated;
>>> use App\Models\Contact;
>>> $contact = Contact::first();
>>> event(new ContactUpdated($contact));
```

### Monitor Pusher Debug Console
1. Log in to Pusher dashboard
2. Navigate to your app
3. Click "Debug Console"
4. Watch for events in real-time

### Monitor Laravel WebSockets
Visit http://localhost:8000/laravel-websockets

---

## Queue Configuration

Broadcasting events should be queued for better performance:

**Already configured in events:**
```php
class ContactUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;
    // ...
}
```

**Ensure queue workers are running:**
```bash
php artisan queue:work redis --queue=default
```

---

## Production Checklist

- [ ] Choose broadcasting option (Pusher recommended)
- [ ] Configure environment variables
- [ ] Install required packages
- [ ] Build frontend assets (`npm run build`)
- [ ] Test events with Tinker
- [ ] Verify queue workers are running
- [ ] Monitor Pusher/WebSocket dashboard
- [ ] Set up SSL for WebSocket connections (production)
- [ ] Configure CORS if needed

---

## Troubleshooting

### Events not broadcasting
1. Check queue workers: `php artisan queue:failed`
2. Check Redis connection: `redis-cli ping`
3. Verify Pusher credentials in Pusher dashboard
4. Check Laravel logs: `tail -f storage/logs/laravel.log`

### Frontend not receiving events
1. Check browser console for errors
2. Verify Echo is initialized: `console.log(window.Echo)`
3. Check Vite environment variables
4. Rebuild assets: `npm run build`

### WebSockets connection refused
1. Ensure WebSocket server is running: `php artisan websockets:serve`
2. Check firewall rules for port 6001
3. Verify PUSHER_HOST and PUSHER_PORT in `.env`

---

## Alternatives (If Broadcasting Not Needed)

If you don't need real-time updates, you can:

1. **Remove broadcasting from jobs:**
   - Delete `ContactBroadcastJob`
   - Delete `DashboardBroadcastJob`
   - Remove broadcast calls from Contact model

2. **Use polling instead:**
   - Set up Livewire polling: `wire:poll.5s`
   - Refresh stats every 5 seconds

3. **Manual refresh:**
   - Users click refresh button to update data

---

**Recommendation:** Start with **Pusher** for simplest setup, migrate to **Laravel WebSockets** if cost becomes an issue at scale.
