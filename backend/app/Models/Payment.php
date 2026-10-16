<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class Payment extends Model {
    protected $fillable = ['order_id', 'received_by_user_id', 'payment_method', 'amount', 'reference_no', 'idempotency_key'];
    protected $casts = ['amount' => 'integer'];
    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
    public function receivedBy(): BelongsTo { return $this->belongsTo(User::class, 'received_by_user_id'); }
}
