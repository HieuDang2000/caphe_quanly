<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Reservation extends Model
{
    protected $fillable = [
        'customer_id', 'table_id', 'reservation_date',
        'start_time', 'end_time', 'guests_count', 'status', 'notes',
    ];

    protected function casts(): array
    {
        return ['reservation_date' => 'date'];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function table(): BelongsTo
    {
        return $this->belongsTo(LayoutObject::class, 'table_id');
    }
}
