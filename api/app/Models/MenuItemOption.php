<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MenuItemOption extends Model
{
    protected $fillable = ['menu_item_id', 'name', 'extra_price'];

    protected function casts(): array
    {
        return [
            'extra_price' => 'decimal:0',
        ];
    }

    public function menuItem(): BelongsTo
    {
        return $this->belongsTo(MenuItem::class);
    }
}
