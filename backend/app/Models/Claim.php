<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class Claim extends Model {
    protected $fillable = ['order_id', 'customer_id', 'claim_type', 'description', 'status', 'resolution', 'refund_amount'];
    protected $casts = ['refund_amount' => 'integer'];
    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
    public function customer(): BelongsTo { return $this->belongsTo(Customer::class); }
}
