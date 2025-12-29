<?php

namespace App\Events;

use App\Models\Contact;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ContactUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Contact $contact;

    /**
     * Create a new event instance.
     */
    public function __construct(Contact $contact)
    {
        $this->contact = $contact;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new Channel('contacts'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'contact.updated';
    }

    /**
     * Get the data to broadcast.
     */
    public function broadcastWith(): array
    {
        return [
            'id' => $this->contact->id,
            'raw_phone_number' => $this->contact->raw_phone_number,
            'formatted_phone_number' => $this->contact->formatted_phone_number,
            'carrier_name' => $this->contact->carrier_name,
            'status' => $this->contact->status,
            'phone_valid' => $this->contact->phone_valid,
            'business_name' => $this->contact->business_name,
            'email' => $this->contact->email,
            'updated_at' => $this->contact->updated_at?->toIso8601String(),
        ];
    }
}
