<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
class Service extends Model {
    protected $fillable = ['branch_id', 'name', 'unit', 'price', 'estimate_duration_hours', 'min_order', 'is_active'];
    protected $casts = ['price' => 'integer', 'min_order' => 'float', 'is_active' => 'boolean'];
    public function branch(): BelongsTo { return $this->belongsTo(Branch::class); }
    public function priceHistories(): HasMany { return $this->hasMany(ServicePriceHistory::class); }
}
