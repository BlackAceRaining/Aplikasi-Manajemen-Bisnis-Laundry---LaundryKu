<?php

namespace App\Http\Controllers;

use App\Models\Customer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $customers = Customer::where('branch_id', $request->user()->branch_id ?? 1)
            ->orderBy('name', 'asc')
            ->get();

        return response()->json([
            'data' => $customers
        ]);
    }

    public function getPoints(Request $request, int $id): JsonResponse
    {
        $customer = Customer::with(['loyaltyTransactions' => function ($q) {
            $q->orderBy('created_at', 'desc');
        }])->findOrFail($id);

        $user = $request->user();

        // RBAC: Pelanggan hanya boleh melihat saldo miliknya sendiri
        if ($user->isCustomer() && $user->customer?->id !== $customer->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Anda tidak memiliki hak akses untuk melihat data poin ini.',
                ]
            ], 403);
        }

        return response()->json([
            'data' => [
                'customer_id' => $customer->id,
                'customer_name' => $customer->name,
                'point_balance' => (int) $customer->point_balance,
                'transactions' => $customer->loyaltyTransactions,
            ]
        ]);
    }
}
