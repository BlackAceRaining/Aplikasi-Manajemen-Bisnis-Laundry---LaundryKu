<?php

namespace App\Console\Commands;

use App\Enums\OrderStatus;
use App\Models\Notification;
use App\Models\Order;
use App\Models\OrderStatusLog;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class LaundryRemindersCommand extends Command
{
    protected $signature = 'laundry:reminders';
    protected $description = 'Kirim notifikasi pengingat pengambilan dan tandai order Tidak Diambil jika lewat due_at';

    public function handle(): int
    {
        $now = Carbon::now('UTC');
        $this->info("Menjalankan laundry:reminders pada {$now->toDateTimeString()} UTC...");

        $siapOrders = Order::with(['customer.user', 'customer.branch'])
            ->where('status', OrderStatus::Siap->value)
            ->whereNotNull('due_at')
            ->get();

        $markedOverdue = 0;
        $remindersSent = 0;

        foreach ($siapOrders as $order) {
            $customerUser = $order->customer?->user;

            // 1. Check if past due_at -> Mark as 'Tidak Diambil'
            if ($now->greaterThanOrEqualTo($order->due_at)) {
                DB::transaction(function () use ($order, $now, &$markedOverdue, $customerUser) {
                    $order->status = OrderStatus::TidakDiambil->value;
                    $order->save();

                    OrderStatusLog::create([
                        'order_id' => $order->id,
                        'from_status' => OrderStatus::Siap->value,
                        'to_status' => OrderStatus::TidakDiambil->value,
                        'changed_by_user_id' => null,
                        'reason' => 'Sistem: Melebihi batas waktu pengambilan (due_at)',
                    ]);

                    if ($customerUser) {
                        Notification::create([
                            'user_id' => $customerUser->id,
                            'order_id' => $order->id,
                            'type' => 'reminder',
                            'title' => 'Cucian Belum Diambil',
                            'message' => "Order #{$order->order_no} telah melebihi batas waktu penyimpanan ({$order->due_at->format('d M Y')}). Silakan hubungi kasir.",
                        ]);
                    }

                    $markedOverdue++;
                });

                continue;
            }

            // 2. Check if near due (< 2 days) -> Send reminder notification
            $leadHours = 48; // 2 days lead time (BR-06)
            $hoursUntilDue = $now->diffInHours($order->due_at, false);

            if ($hoursUntilDue <= $leadHours && $hoursUntilDue > 0 && $customerUser) {
                // Avoid spamming if reminder already sent today
                $alreadySent = Notification::where('user_id', $customerUser->id)
                    ->where('order_id', $order->id)
                    ->where('type', 'reminder')
                    ->where('created_at', '>=', $now->copy()->subHours(24))
                    ->exists();

                if (!$alreadySent) {
                    Notification::create([
                        'user_id' => $customerUser->id,
                        'order_id' => $order->id,
                        'type' => 'reminder',
                        'title' => 'Pengingat Batas Pengambilan',
                        'message' => "Halo {$order->customer->name}, cucian Anda #{$order->order_no} siap diambil. Batas pengambilan: {$order->due_at->format('d M Y H:i')} WITA.",
                    ]);
                    $remindersSent++;
                }
            }
        }

        $this->info("Selesai. {$markedOverdue} order ditandai Tidak Diambil, {$remindersSent} pengingat dikirim.");
        return self::SUCCESS;
    }
}
