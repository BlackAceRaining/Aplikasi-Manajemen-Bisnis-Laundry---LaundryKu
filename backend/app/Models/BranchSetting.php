<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class BranchSetting extends Model {
    protected $fillable = ['branch_id', 'holding_period_days', 'reminder_lead_days', 'points_per_amount', 'amount_per_point'];
    public function branch(): BelongsTo { return $this->belongsTo(Branch::class); }
}
