<?php

namespace App\Http\Controllers;

use App\Models\Customer;
use App\Models\LoyaltyTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

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

    public function redeemPoints(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'points' => 'required|integer|min:1',
            'description' => 'nullable|string|max:255',
        ]);

        $customer = Customer::findOrFail($id);
        $user = $request->user();

        // RBAC: Pelanggan hanya boleh menukar poin miliknya sendiri
        if ($user->isCustomer() && $user->customer?->id !== $customer->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Anda tidak memiliki hak akses untuk menukar poin pelanggan ini.',
                ]
            ], 403);
        }

        $points = (int) $request->input('points');
        $description = $request->input('description') ?? "Tukar potongan {$points} poin";

        return DB::transaction(function () use ($customer, $points, $description) {
            $customer = Customer::where('id', $customer->id)->lockForUpdate()->firstOrFail();

            if ($customer->point_balance < $points) {
                return response()->json([
                    'error' => [
                        'code' => 'INSUFFICIENT_POINTS',
                        'message' => "Poin tidak mencukupi. Saldo Anda saat ini: {$customer->point_balance} poin.",
                    ]
                ], 422);
            }

            $newBalance = $customer->point_balance - $points;
            $customer->point_balance = $newBalance;
            $customer->save();

            $transaction = LoyaltyTransaction::create([
                'customer_id' => $customer->id,
                'order_id' => null,
                'type' => 'redeem',
                'points' => $points,
                'balance_after' => $newBalance,
                'description' => $description,
            ]);

            return response()->json([
                'data' => [
                    'message' => 'Poin berhasil ditukarkan.',
                    'point_balance' => $newBalance,
                    'transaction' => $transaction,
                ]
            ]);
        });
    }
}
