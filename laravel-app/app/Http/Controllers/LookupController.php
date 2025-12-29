<?php

namespace App\Http\Controllers;

use App\Models\Contact;
use App\Jobs\LookupRequestJob;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class LookupController extends Controller
{
    /**
     * Limit batch size to prevent overwhelming the queue
     */
    private const MAX_BATCH_SIZE = 1000;

    /**
     * Queue contacts for bulk lookup processing
     *
     * Requires authentication via Filament admin middleware
     */
    public function run(Request $request)
    {
        // Count contacts to process (not_processed scope from Contact model)
        $contactsToProcess = Contact::notProcessed();

        if ($contactsToProcess->count() === 0) {
            return redirect()
                ->route('filament.admin.resources.contacts.index')
                ->with('error', 'No contacts to process. All contacts have been looked up.');
        }

        // Queue only pending/failed contacts for processing (with batch limit)
        $queuedCount = 0;
        $totalPending = $contactsToProcess->count();

        $contactsToProcess->limit(self::MAX_BATCH_SIZE)->each(function ($contact) use (&$queuedCount) {
            // Skip if already processing or completed
            if (in_array($contact->status, ['processing', 'completed'])) {
                return;
            }

            LookupRequestJob::dispatch($contact->id);
            $queuedCount++;
        });

        Log::info("Queued {$queuedCount} contacts for lookup processing ({$totalPending} total pending)");

        $noticeMessage = $totalPending > self::MAX_BATCH_SIZE
            ? "Successfully queued {$queuedCount} contacts for lookup (" . ($totalPending - $queuedCount) . " remaining). Run again to process more."
            : "Successfully queued {$queuedCount} contacts for lookup. Processing will continue in the background.";

        return redirect()
            ->route('filament.admin.resources.contacts.index')
            ->with('success', $noticeMessage);
    }
}
