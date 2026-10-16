<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use App\Services\JwtService;
use App\Models\User;

class JwtAuthMiddleware
{
    protected JwtService $jwtService;

    public function __construct(JwtService $jwtService)
    {
        $this->jwtService = $jwtService;
    }

    public function handle(Request $request, Closure $next): Response
    {
        $authHeader = $request->header('Authorization');
        if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
            return response()->json([
                'error' => [
                    'code' => 'UNAUTHORIZED',
                    'message' => 'Token otentikasi tidak ditemukan.',
                ]
            ], 401);
        }

        $token = substr($authHeader, 7);
        $payload = $this->jwtService->decodeToken($token);

        if (!$payload || !isset($payload->sub)) {
            return response()->json([
                'error' => [
                    'code' => 'UNAUTHORIZED',
                    'message' => 'Token otentikasi tidak valid atau telah kedaluwarsa.',
                ]
            ], 401);
        }

        $user = User::with(['role', 'branch', 'customer'])->find($payload->sub);
        if (!$user || !$user->is_active) {
            return response()->json([
                'error' => [
                    'code' => 'UNAUTHORIZED',
                    'message' => 'Pengguna tidak ditemukan atau dinonaktifkan.',
                ]
            ], 401);
        }

        $request->setUserResolver(fn () => $user);
        $request->attributes->set('auth_user', $user);

        return $next($request);
    }
}
