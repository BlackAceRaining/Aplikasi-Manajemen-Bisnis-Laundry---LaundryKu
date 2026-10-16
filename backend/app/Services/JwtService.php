<?php

namespace App\Services;

use App\Models\User;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Exception;

class JwtService
{
    private string $secret;
    private int $ttl;

    public function __construct()
    {
        $this->secret = config('app.jwt_secret', env('JWT_SECRET', 'laundryku_super_secret_jwt_key_2026_demo_sec'));
        $this->ttl = (int) config('app.jwt_ttl', env('JWT_TTL', 86400));
    }

    public function generateToken(User $user): string
    {
        $payload = [
            'iss' => config('app.url', 'http://localhost:8000'),
            'sub' => $user->id,
            'role' => $user->role?->name,
            'email' => $user->email,
            'iat' => time(),
            'exp' => time() + $this->ttl,
        ];

        return JWT::encode($payload, $this->secret, 'HS256');
    }

    public function decodeToken(string $token): ?object
    {
        try {
            return JWT::decode($token, new Key($this->secret, 'HS256'));
        } catch (Exception) {
            return null;
        }
    }
}
