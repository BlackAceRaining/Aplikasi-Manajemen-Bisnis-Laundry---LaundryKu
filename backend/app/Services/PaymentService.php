<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\CashTransaction;
use App\Models\Customer;
use App\Models\LoyaltyTransaction;
use App\Models\Order;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PaymentService
{
    protected OrderService $orderService;

    public function __construct(OrderService $orderService)
    {
        $this->orderService = $orderService;
    }

    /**
     * Process payment atomically (P-09).
     */
    public function processPayment(
        Order $order,
        int $amount,
        string $method,
        User $actor,
        ?string $referenceNo = null,
        ?string $idempotencyKey = null
    ): Payment {
        // Check idempotency key if provided
        if ($idempotencyKey) {
            $existingPayment = Payment::where('order_id', $order->id)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if ($existingPayment) {
                return $existingPayment;
            }
        }

        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => 'Jumlah pembayaran harus lebih besar dari 0.',
            ]);
        }

        return DB::transaction(function () use ($order, $amount, $method, $actor, $referenceNo, $idempotencyKey) {
            // Lock order for update
            $order = Order::where('id', $order->id)->lockForUpdate()->firstOrFail();

            // Total already paid
            $alreadyPaid = (int) $order->payments()->sum('amount');
            $remaining = max(0, $order->total_amount - $alreadyPaid);

            if ($remaining <= 0 && $order->status === OrderStatus::Lunas->value) {
                throw ValidationException::withMessages([
                    'order' => 'Order ini sudah lunas sebelumnya.',
                ]);
            }

            // 1. Create Payment record
            $payment = Payment::create([
                'order_id' => $order->id,
                'received_by_user_id' => $actor->id,
                'payment_method' => $method,
                'amount' => $amount,
                'reference_no' => $referenceNo,
                'idempotency_key' => $idempotencyKey,
            ]);

            // 2. Create CashTransaction (Append-only)
            CashTransaction::create([
                'branch_id' => $order->branch_id,
                'order_id' => $order->id,
                'user_id' => $actor->id,
                'transaction_type' => 'in',
                'category' => 'payment',
                'amount' => $amount,
                'description' => "Pembayaran Order #{$order->order_no} via " . strtoupper($method),
            ]);

            // Check if fully paid now
            $newTotalPaid = $alreadyPaid + $amount;
            if ($newTotalPaid >= $order->total_amount) {
                // If order was Diambil, advance to Lunas and then Selesai
                if ($order->status === OrderStatus::Diambil->value || $order->status === OrderStatus::Siap->value) {
                    if ($order->status === OrderStatus::Siap->value) {
                        $this->orderService->transition($order, OrderStatus::Diambil, $actor, 'Pengambilan cucian saat pembayaran');
                    }
                    $this->orderService->transition($order, OrderStatus::Lunas, $actor, 'Pembayaran lunas');
                    $this->orderService->transition($order, OrderStatus::Selesai, $actor, 'Order selesai otomatis');
                }

                // 3. Loyalty Points (BR-08: 1 poin per Rp10.000 total order)
                $earnedPoints = (int) intdiv($order->total_amount, 10000);

                if ($earnedPoints > 0) {
                    $customer = Customer::where('id', $order->customer_id)->lockForUpdate()->firstOrFail();
                    $newBalance = $customer->point_balance + $earnedPoints;
                    $customer->point_balance = $newBalance;
                    $customer->save();

                    // Append-only loyalty transaction
                    LoyaltyTransaction::create([
                        'customer_id' => $customer->id,
                        'order_id' => $order->id,
                        'type' => 'earn',
                        'points' => $earnedPoints,
                        'balance_after' => $newBalance,
                        'description' => "Poin dari transaksi #{$order->order_no}",
                    ]);
                }
            }

            return $payment->load(['order', 'receivedBy']);
        });
    }
}
