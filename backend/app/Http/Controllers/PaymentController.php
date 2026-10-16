<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class PaymentController extends Controller
{
    protected PaymentService $paymentService;

    public function __construct(PaymentService $paymentService)
    {
        $this->paymentService = $paymentService;
    }

    public function store(Request $request, int $orderId): JsonResponse
    {
        $order = Order::findOrFail($orderId);

        $request->validate([
            'amount' => 'required|integer|min:1',
            'payment_method' => 'required|string|in:cash,transfer',
            'reference_no' => 'nullable|string',
        ]);

        $idempotencyKey = $request->header('Idempotency-Key');
        $user = $request->user();

        try {
            $payment = $this->paymentService->processPayment(
                $order,
                (int) $request->amount,
                $request->payment_method,
                $user,
                $request->reference_no,
                $idempotencyKey
            );

            return response()->json([
                'data' => $payment
            ], 201);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => [
                    'code' => 'PAYMENT_FAILED',
                    'message' => $e->validator->errors()->first(),
                ]
            ], 422);
        }
    }
}
