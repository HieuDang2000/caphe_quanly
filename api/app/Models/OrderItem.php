<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends Model
{
    protected $fillable = ['order_id', 'menu_item_id', 'quantity', 'unit_price', 'subtotal', 'notes', 'options', 'is_paid'];

    protected function casts(): array
    {
        return [
            'unit_price' => 'decimal:0',
            'subtotal' => 'decimal:0',
            'options' => 'array',
            'is_paid' => 'boolean',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function menuItem(): BelongsTo
    {
        return $this->belongsTo(MenuItem::class);
    }
}
