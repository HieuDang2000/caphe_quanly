<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Floor extends Model
{
    protected $fillable = ['name', 'floor_number', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    public function layoutObjects(): HasMany
    {
        return $this->hasMany(LayoutObject::class);
    }

    public function tables(): HasMany
    {
        return $this->hasMany(LayoutObject::class)->where('type', 'table');
    }
}
