<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Order extends Model
{
    protected $fillable = [
        'user_id', 'customer_id', 'table_id', 'order_number',
        'status', 'subtotal', 'tax', 'discount', 'total', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:0',
            'tax' => 'decimal:0',
            'discount' => 'decimal:0',
            'total' => 'decimal:0',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function table(): BelongsTo
    {
        return $this->belongsTo(LayoutObject::class, 'table_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function invoice(): HasOne
    {
        return $this->hasOne(Invoice::class);
    }

    public function recalculate(): void
    {
        // Chỉ tính lại trên các item chưa được thanh toán (is_paid = false)
        $subtotal = $this->items()
            ->where('is_paid', false)
            ->sum('subtotal');
        $tax = 0;
        $total = $subtotal - $this->discount;
        $this->update(compact('subtotal', 'tax', 'total'));
    }
}
