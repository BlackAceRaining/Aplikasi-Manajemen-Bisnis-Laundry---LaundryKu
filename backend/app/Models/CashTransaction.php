<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class CashTransaction extends Model {
    protected $fillable = ['branch_id', 'order_id', 'user_id', 'transaction_type', 'category', 'amount', 'description'];
    protected $casts = ['amount' => 'integer'];
    public function branch(): BelongsTo { return $this->belongsTo(Branch::class); }
    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
}
