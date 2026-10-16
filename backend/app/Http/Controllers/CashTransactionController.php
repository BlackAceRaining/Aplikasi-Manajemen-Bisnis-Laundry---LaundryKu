<?php

namespace App\Http\Controllers;

use App\Models\CashTransaction;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CashTransactionController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'amount' => 'required|integer|min:1',
            'category' => 'required|string|max:50',
            'description' => 'required|string|max:255',
        ]);

        $user = $request->user();
        $branchId = $user->branch_id ?? 1;

        $transaction = CashTransaction::create([
            'branch_id' => $branchId,
            'order_id' => null,
            'user_id' => $user->id,
            'transaction_type' => 'out',
            'category' => $request->category,
            'amount' => (int) $request->amount,
            'description' => $request->description,
        ]);

        AuditService::log(
            action: 'record_expense',
            entityType: 'CashTransaction',
            entityId: (string) $transaction->id,
            oldValues: null,
            newValues: $transaction->toArray(),
            userId: $user->id
        );

        return response()->json([
            'data' => $transaction
        ], 201);
    }
}
