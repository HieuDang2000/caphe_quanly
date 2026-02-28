<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Order extends Model
{
    protected $fillable = [
        'user_id',
        'customer_id',
        'table_id',
        'order_number',
        'status',
        'subtotal',
        'tax',
        'discount',
        'total',
        'total_all',
        'highest_total',
        'notes',
        'order_history',
        'is_deleted_item',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:0',
            'tax' => 'decimal:0',
            'discount' => 'decimal:0',
            'total' => 'decimal:0',
            'total_all' => 'decimal:0',
            'highest_total' => 'decimal:0',
            'is_deleted_item' => 'boolean',
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

        // total_all = tổng tất cả item (kể cả đã thanh toán) - discount; không bị trừ khi thanh toán một phần
        $subtotalAll = $this->items()->sum('subtotal');
        $totalAll = $subtotalAll - $this->discount;

        $this->update([
            'subtotal' => $subtotal,
            'tax' => $tax,
            'total' => $total,
            'total_all' => $totalAll,
        ]);
    }

    /**
     * Thêm một dòng vào order_history (phân cách bằng dấu ; giữa các thao tác).
     */
    public function appendHistory(string $entry): void
    {
        $entry = str_replace(';', ' ', trim($entry));
        if ($entry === '') {
            return;
        }
        $current = $this->order_history ?? '';
        $new = $current === '' ? $entry : $current . ';' . $entry;
        $this->update(['order_history' => $new]);
    }
}
