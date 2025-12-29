<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use Illuminate\Http\Request;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;

class BaseController extends Controller
{
    /**
     * The authenticated API user
     */
    protected ?AdminUser $currentUser = null;

    /**
     * Create a new controller instance
     */
    public function __construct()
    {
        $this->middleware(function (Request $request, $next) {
            $this->authenticateApiToken($request);
            return $next($request);
        });
    }

    /**
     * Authenticate API token from Authorization header
     */
    protected function authenticateApiToken(Request $request): void
    {
        $token = $request->bearerToken();

        if (!$token) {
            abort(401, 'Unauthorized: Missing API token');
        }

        $this->currentUser = AdminUser::where('api_token', $token)->first();

        if (!$this->currentUser) {
            abort(401, 'Unauthorized: Invalid API token');
        }
    }

    /**
     * Get the authenticated user
     */
    protected function getCurrentUser(): ?AdminUser
    {
        return $this->currentUser;
    }

    /**
     * Handle model not found exceptions
     */
    protected function handleNotFound(\Exception $e)
    {
        return response()->json([
            'error' => 'Not Found',
            'message' => $e->getMessage(),
        ], 404);
    }

    /**
     * Handle validation exceptions
     */
    protected function handleValidationException(ValidationException $e)
    {
        return response()->json([
            'error' => 'Unprocessable Entity',
            'errors' => $e->errors(),
        ], 422);
    }

    /**
     * Handle bad request exceptions
     */
    protected function handleBadRequest(\Exception $e)
    {
        return response()->json([
            'error' => 'Bad Request',
            'message' => $e->getMessage(),
        ], 400);
    }
}
