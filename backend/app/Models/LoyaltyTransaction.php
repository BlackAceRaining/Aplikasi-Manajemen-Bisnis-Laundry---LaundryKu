<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class LoyaltyTransaction extends Model {
    protected $fillable = ['customer_id', 'order_id', 'type', 'points', 'balance_after', 'description'];
    public function customer(): BelongsTo { return $this->belongsTo(Customer::class); }
    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
}
