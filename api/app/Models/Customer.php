<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Customer extends Model
{
    protected $fillable = ['name', 'phone', 'email', 'points', 'tier'];

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function pointsHistory(): HasMany
    {
        return $this->hasMany(CustomerPoint::class);
    }

    public function reservations(): HasMany
    {
        return $this->hasMany(Reservation::class);
    }

    public function updateTier(): void
    {
        $this->tier = match (true) {
            $this->points >= 5000 => 'platinum',
            $this->points >= 2000 => 'gold',
            $this->points >= 500 => 'silver',
            default => 'regular',
        };
        $this->save();
    }
}
