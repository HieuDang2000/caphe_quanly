<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Invoice extends Model
{
    protected $fillable = [
        'order_id', 'invoice_number', 'subtotal', 'tax_rate',
        'tax_amount', 'discount_amount', 'total', 'payment_status',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:0',
            'tax_rate' => 'decimal:2',
            'tax_amount' => 'decimal:0',
            'discount_amount' => 'decimal:0',
            'total' => 'decimal:0',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function totalPaid(): int
    {
        return (int) $this->payments()->sum('amount');
    }
}
