<?php

namespace App\Http\Controllers\Api\V1;

use App\Models\Contact;
use App\Jobs\LookupRequestJob;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ContactsController extends BaseController
{
    /**
     * Display a listing of contacts
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function index(Request $request)
    {
        try {
            $page = $request->input('page', 1);
            $perPage = 25;

            $contacts = Contact::orderBy('created_at', 'desc')
                ->paginate($perPage, ['*'], 'page', $page);

            return response()->json([
                'contacts' => $contacts->map(fn($c) => $this->contactJson($c)),
                'meta' => [
                    'current_page' => $contacts->currentPage(),
                    'total_pages' => $contacts->lastPage(),
                    'total_count' => $contacts->total(),
                    'per_page' => $contacts->perPage(),
                ],
            ]);
        } catch (\Exception $e) {
            return $this->handleBadRequest($e);
        }
    }

    /**
     * Display the specified contact
     *
     * @param  int  $id
     * @return \Illuminate\Http\JsonResponse
     */
    public function show($id)
    {
        try {
            $contact = Contact::findOrFail($id);
            return response()->json([
                'contact' => $this->contactJson($contact),
            ]);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->handleNotFound($e);
        }
    }

    /**
     * Store a newly created contact or reset existing one
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function store(Request $request)
    {
        try {
            $request->validate([
                'phone_number' => 'required|string',
            ]);

            $contact = Contact::firstOrNew([
                'raw_phone_number' => $request->input('phone_number'),
            ]);

            // Reset failed contacts to a clean pending state
            $saved = false;
            if ($contact->exists && $contact->status === 'failed') {
                $saved = $contact->resetForReprocessing();
            } else {
                if (!$contact->exists) {
                    $contact->status = 'pending';
                }
                $saved = $contact->save();
            }

            if ($saved) {
                // Trigger processing immediately if pending
                if ($contact->status === 'pending') {
                    LookupRequestJob::dispatch($contact->id);
                }

                return response()->json([
                    'contact' => $this->contactJson($contact),
                ], 201);
            }

            return response()->json([
                'errors' => $contact->getErrors(),
            ], 422);
        } catch (ValidationException $e) {
            return $this->handleValidationException($e);
        } catch (\Exception $e) {
            return $this->handleBadRequest($e);
        }
    }

    /**
     * Transform contact to JSON format
     *
     * @param  Contact  $contact
     * @return array
     */
    private function contactJson(Contact $contact): array
    {
        return [
            'id' => $contact->id,
            'phone_number' => $contact->formatted_phone_number ?? $contact->raw_phone_number,
            'status' => $contact->status,
            'carrier' => $contact->carrier_name,
            'type' => $contact->line_type,
            'country' => $contact->country_code,
            'valid' => $contact->phone_valid,
            'created_at' => $contact->created_at?->toIso8601String(),
            'updated_at' => $contact->updated_at?->toIso8601String(),
        ];
    }
}
