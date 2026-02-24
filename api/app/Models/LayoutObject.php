<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LayoutObject extends Model
{
    protected $fillable = [
        'floor_id', 'type', 'name', 'position_x', 'position_y',
        'width', 'height', 'rotation', 'properties', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'properties' => 'array',
            'position_x' => 'double',
            'position_y' => 'double',
            'width' => 'double',
            'height' => 'double',
            'rotation' => 'double',
            'is_active' => 'boolean',
        ];
    }

    public function floor(): BelongsTo
    {
        return $this->belongsTo(Floor::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'table_id');
    }

    public function activeOrder()
    {
        return $this->hasOne(Order::class, 'table_id')
            ->whereIn('status', ['pending', 'in_progress'])
            ->latest();
    }

    public function reservations(): HasMany
    {
        return $this->hasMany(Reservation::class, 'table_id');
    }
}
