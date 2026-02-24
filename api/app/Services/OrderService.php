<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\MenuItem;
use Illuminate\Support\Str;

class OrderService
{
    public function createOrder(array $data, int $userId): Order
    {
        $order = Order::create([
            'user_id' => $userId,
            'customer_id' => $data['customer_id'] ?? null,
            'table_id' => $data['table_id'] ?? null,
            'order_number' => $this->generateOrderNumber(),
            'status' => 'pending',
            'notes' => $data['notes'] ?? null,
            'discount' => $data['discount'] ?? 0,
        ]);

        if (!empty($data['items'])) {
            $this->syncItems($order, $data['items']);
        }

        $order->recalculate();
        $order->load(['items.menuItem', 'table', 'user', 'customer']);

        return $order;
    }

    public function updateOrder(Order $order, array $data): Order
    {
        $order->update(collect($data)->only(['customer_id', 'table_id', 'notes', 'discount'])->toArray());

        if (isset($data['items'])) {
            $order->items()->delete();
            $this->syncItems($order, $data['items']);
        }

        $order->recalculate();
        $order->load(['items.menuItem', 'table', 'user', 'customer']);

        return $order;
    }

    protected function syncItems(Order $order, array $items): void
    {
        foreach ($items as $itemData) {
            $menuItem = MenuItem::findOrFail($itemData['menu_item_id']);
            $quantity = $itemData['quantity'] ?? 1;

            OrderItem::create([
                'order_id' => $order->id,
                'menu_item_id' => $menuItem->id,
                'quantity' => $quantity,
                'unit_price' => $menuItem->price,
                'subtotal' => $menuItem->price * $quantity,
                'notes' => $itemData['notes'] ?? null,
            ]);
        }
    }

    protected function generateOrderNumber(): string
    {
        $date = now()->format('Ymd');
        $count = Order::whereDate('created_at', today())->count() + 1;
        return "ORD-{$date}-" . str_pad($count, 4, '0', STR_PAD_LEFT);
    }
}
