<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class OrderPhoto extends Model {
    protected $fillable = ['order_id', 'photo_path', 'photo_type', 'uploaded_by_user_id'];
    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
    public function uploadedBy(): BelongsTo { return $this->belongsTo(User::class, 'uploaded_by_user_id'); }
}
