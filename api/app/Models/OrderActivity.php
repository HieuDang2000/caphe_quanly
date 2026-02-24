<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderActivity extends Model
{
    protected $fillable = ['order_id', 'user_id', 'action', 'description', 'payload'];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public static function log(int $orderId, int $userId, string $action, ?string $description = null, ?array $payload = null): self
    {
        return self::create([
            'order_id' => $orderId,
            'user_id' => $userId,
            'action' => $action,
            'description' => $description,
            'payload' => $payload,
        ]);
    }
}
