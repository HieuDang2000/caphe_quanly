<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\MenuItem;
use App\Models\MenuItemOption;

class OrderService
{
    public function createOrder(array $data, int $userId): Order
    {
        $tableId = $data['table_id'] ?? null;
        if ($tableId !== null && !empty($data['items'])) {
            $existingOrder = $this->findActiveOrderForTable((int) $tableId);
            if ($existingOrder !== null) {
                $this->addItemsToOrder($existingOrder, $data['items'], $userId);
                return $existingOrder;
            }
        }

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

    public function findActiveOrderForTable(int $tableId): ?Order
    {
        return Order::where('table_id', $tableId)
            ->whereIn('status', ['pending', 'in_progress'])
            ->orderByDesc('created_at')
            ->first();
    }

    public function addItemsToOrder(Order $order, array $items, int $userId): Order
    {
        foreach ($items as $itemData) {
            [$unitPrice, $optionsSnapshot] = $this->resolveUnitPriceAndOptions($itemData);
            $quantity = (int) ($itemData['quantity'] ?? 1);
            $subtotal = $unitPrice * $quantity;

            OrderItem::create([
                'order_id' => $order->id,
                'menu_item_id' => $itemData['menu_item_id'],
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
                'subtotal' => $subtotal,
                'notes' => $itemData['notes'] ?? null,
                'options' => $optionsSnapshot,
            ]);
        }

        $order->recalculate();
        $order->load(['items.menuItem', 'table', 'user', 'customer']);

        return $order;
    }

    public function updateOrder(Order $order, array $data, int $userId): Order
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
            [$unitPrice, $optionsSnapshot] = $this->resolveUnitPriceAndOptions($itemData);
            $quantity = (int) ($itemData['quantity'] ?? 1);
            $subtotal = $unitPrice * $quantity;

            OrderItem::create([
                'order_id' => $order->id,
                'menu_item_id' => $itemData['menu_item_id'],
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
                'subtotal' => $subtotal,
                'notes' => $itemData['notes'] ?? null,
                'options' => $optionsSnapshot,
            ]);
        }
    }

    /**
     * @return array{0: float|int, 1: array<int, array{id: int, name: string, extra_price: mixed}>}
     */
    protected function resolveUnitPriceAndOptions(array $itemData): array
    {
        $menuItem = MenuItem::findOrFail($itemData['menu_item_id']);
        $basePrice = (float) $menuItem->price;
        $optionsSnapshot = [];
        $optionsTotal = 0;

        $optionsRaw = $itemData['options'] ?? [];
        foreach ($optionsRaw as $opt) {
            $id = $opt['id'] ?? null;
            $name = $opt['name'] ?? null;
            $extraPrice = isset($opt['extra_price']) ? (float) $opt['extra_price'] : null;

            $resolvedId = $id;
            if ($id !== null) {
                $option = MenuItemOption::where('id', $id)->where('menu_item_id', $menuItem->id)->first();
                if ($option) {
                    $resolvedId = $option->id;
                    $name = $option->name;
                    $extraPrice = (float) $option->extra_price;
                }
            }
            if ($name !== null && $extraPrice !== null) {
                $optionsSnapshot[] = ['id' => $resolvedId, 'name' => $name, 'extra_price' => $extraPrice];
                $optionsTotal += $extraPrice;
            }
        }

        return [$basePrice + $optionsTotal, $optionsSnapshot];
    }

    protected function generateOrderNumber(): string
    {
        $date = now()->format('Ymd');
        $count = Order::whereDate('created_at', today())->count() + 1;
        return "ORD-{$date}-" . str_pad($count, 4, '0', STR_PAD_LEFT);
    }
}
