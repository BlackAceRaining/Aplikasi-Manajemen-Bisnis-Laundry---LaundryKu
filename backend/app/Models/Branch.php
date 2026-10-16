<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;
class Branch extends Model {
    protected $fillable = ['code', 'name', 'address', 'phone', 'is_active'];
    protected $casts = ['is_active' => 'boolean'];
    public function settings(): HasOne { return $this->hasOne(BranchSetting::class); }
    public function services(): HasMany { return $this->hasMany(Service::class); }
    public function orders(): HasMany { return $this->hasMany(Order::class); }
}
