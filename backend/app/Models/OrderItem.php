<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class OrderItem extends Model {
    protected $fillable = ['order_id', 'service_id', 'service_name_snap', 'unit_snap', 'unit_price', 'quantity', 'subtotal'];
    protected $casts = ['unit_price' => 'integer', 'quantity' => 'float', 'subtotal' => 'integer'];
    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
    public function service(): BelongsTo { return $this->belongsTo(Service::class); }
}
