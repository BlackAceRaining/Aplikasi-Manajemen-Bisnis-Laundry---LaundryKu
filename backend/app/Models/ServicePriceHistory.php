<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class ServicePriceHistory extends Model {
    protected $fillable = ['service_id', 'old_price', 'new_price', 'changed_by_user_id', 'reason'];
    protected $casts = ['old_price' => 'integer', 'new_price' => 'integer'];
    public function service(): BelongsTo { return $this->belongsTo(Service::class); }
    public function changedBy(): BelongsTo { return $this->belongsTo(User::class, 'changed_by_user_id'); }
}
