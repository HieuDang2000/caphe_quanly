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
        if ($tableId !== null && ! empty($data['items'])) {
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

        if (! empty($data['items'])) {
            $this->syncItems($order, $data['items']);
            $names = $this->getOrderItemNamesSummary($order);
            $order->appendHistory($names !== '' ? 'Tạo đơn: ' . $names : 'Tạo đơn');
        } else {
            $order->appendHistory('Tạo đơn');
        }

        $order->recalculate();
        $order->load(['items.menuItem', 'table', 'user', 'customer']);

        return $order;
    }

    public function findActiveOrderForTable(int $tableId): ?Order
    {
        return Order::where('table_id', $tableId)
            ->where('status', 'pending')
            ->orderByDesc('created_at')
            ->first();
    }

    public function addItemsToOrder(Order $order, array $items, int $userId): Order
    {
        $names = [];
        foreach ($items as $itemData) {
            [$unitPrice, $optionsSnapshot] = $this->resolveUnitPriceAndOptions($itemData);
            $quantity = (int) ($itemData['quantity'] ?? 1);
            $subtotal = $unitPrice * $quantity;

            $menuItem = MenuItem::find($itemData['menu_item_id']);
            $name = $menuItem ? trim((string) $menuItem->name) : ('Món #' . $itemData['menu_item_id']);
            $names[] = $name . ' x' . $quantity;

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

        $order->appendHistory($names !== [] ? 'Thêm món: ' . implode(', ', $names) : 'Thêm món');
        $order->recalculate();
        $order->load(['items.menuItem', 'table', 'user', 'customer']);

        return $order;
    }

    /**
     * Gộp toàn bộ các đơn pending của bàn nguồn vào bàn đích ở mức order.
     *
     * Quy ước:
     * - Nếu bàn đích chưa có đơn pending: chỉ cần chuyển table_id các đơn pending từ source sang target.
     * - Nếu cả hai cùng có đơn pending:
     *   - Gộp toàn bộ item của các đơn source sang đơn mới nhất của bàn đích.
     *   - Các đơn source sau khi gộp sẽ được đánh dấu cancelled và bỏ liên kết bàn.
     */
    public function mergeTables(int $sourceTableId, int $targetTableId): void
    {
        if ($sourceTableId === $targetTableId) {
            return;
        }

        $sourceOrders = Order::with('items')
            ->where('table_id', $sourceTableId)
            ->where('status', 'pending')
            ->orderBy('created_at')
            ->get();

        if ($sourceOrders->isEmpty()) {
            return;
        }

        $targetOrder = $this->findActiveOrderForTable($targetTableId);

        // Nếu bàn đích chưa có đơn pending: chỉ chuyển table_id
        if ($targetOrder === null) {
            foreach ($sourceOrders as $order) {
                $order->update(['table_id' => $targetTableId]);
                $order->appendHistory('Chuyển bàn');
            }
            return;
        }

        // Cả hai bàn đều có pending: gộp vào đơn mới nhất của bàn đích
        /** @var Order $targetOrder */
        foreach ($sourceOrders as $order) {
            if ($order->id === $targetOrder->id) {
                continue;
            }

            foreach ($order->items as $item) {
                // Tạo item mới trên order đích, giữ nguyên snapshot giá/options
                OrderItem::create([
                    'order_id' => $targetOrder->id,
                    'menu_item_id' => $item->menu_item_id,
                    'quantity' => $item->quantity,
                    'unit_price' => $item->unit_price,
                    'subtotal' => $item->subtotal,
                    'notes' => $item->notes,
                    'options' => $item->options,
                ]);
            }

            // Đánh dấu đơn nguồn đã được gộp
            $order->update([
                'status' => 'cancelled',
                'table_id' => null,
            ]);
            $order->appendHistory('Đã gộp vào bàn khác');
        }

        $targetOrder->appendHistory('Gộp bàn');
        $targetOrder->recalculate();
    }

    /**
     * Chuyển đơn giữa các bàn.
     *
     * - Nếu truyền orderId: chỉ move đơn đó sang bàn đích (vẫn giữ status hiện tại).
     * - Nếu không: move toàn bộ đơn pending của bàn nguồn sang bàn đích.
     */
    public function moveTable(int $sourceTableId, int $targetTableId, ?int $orderId = null): void
    {
        if ($sourceTableId === $targetTableId) {
            return;
        }

        if ($orderId !== null) {
            $order = Order::where('id', $orderId)
                ->where('table_id', $sourceTableId)
                ->firstOrFail();

            /** @var Order $order */
            $order->update(['table_id' => $targetTableId]);
            $order->appendHistory('Chuyển bàn');
            return;
        }

        $orders = Order::where('table_id', $sourceTableId)
            ->where('status', 'pending')
            ->get();
        foreach ($orders as $order) {
            $order->update(['table_id' => $targetTableId]);
            $order->appendHistory('Chuyển bàn');
        }
    }

    public function updateOrder(Order $order, array $data, int $userId): Order
    {
        $order->update(collect($data)->only(['customer_id', 'table_id', 'notes', 'discount'])->toArray());

        if (isset($data['items'])) {
            $unpaidItems = $order->items()->where('is_paid', false)->with('menuItem')->get();
            $oldCounts = []; // menu_item_id => total quantity
            foreach ($unpaidItems as $i) {
                $oldCounts[$i->menu_item_id] = ($oldCounts[$i->menu_item_id] ?? 0) + $i->quantity;
            }
            $newCounts = [];
            foreach ($data['items'] as $item) {
                $id = (int) ($item['menu_item_id'] ?? 0);
                $qty = (int) ($item['quantity'] ?? 1);
                $newCounts[$id] = ($newCounts[$id] ?? 0) + $qty;
            }
            $allIds = array_unique(array_merge(array_keys($oldCounts), array_keys($newCounts)));
            $namesById = MenuItem::whereIn('id', $allIds)->pluck('name', 'id')->map(fn ($n) => trim((string) $n))->toArray();

            $removedParts = [];
            $addedParts = [];
            foreach ($allIds as $id) {
                $oldQty = $oldCounts[$id] ?? 0;
                $newQty = $newCounts[$id] ?? 0;
                $name = $namesById[$id] ?? ('Món #' . $id);
                if ($oldQty > $newQty) {
                    $removedParts[] = $name . ' x' . ($oldQty - $newQty);
                }
                if ($newQty > $oldQty) {
                    $addedParts[] = $name . ' x' . ($newQty - $oldQty);
                }
            }

            $order->items()->where('is_paid', false)->delete();
            $this->syncItems($order, $data['items']);

            if ($removedParts !== []) {
                $order->appendHistory('Xóa món: ' . implode(', ', $removedParts));
                $order->update(['is_deleted_item' => true]);
            }
            if ($addedParts !== []) {
                $order->appendHistory('Thêm món: ' . implode(', ', $addedParts));
            }
            if ($removedParts === [] && $addedParts === []) {
                $order->appendHistory('Sửa món');
            }
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

    /**
     * Tóm tắt tên món + số lượng từ các item hiện có của order (vd: "Cà phê đen x2, Bánh mì x1").
     */
    protected function getOrderItemNamesSummary(Order $order): string
    {
        $items = $order->items()->with('menuItem')->get();
        $parts = $items->map(function ($i) {
            $name = $i->menuItem ? trim((string) $i->menuItem->name) : ('Món #' . $i->menu_item_id);
            return $name . ' x' . $i->quantity;
        });

        return $parts->join(', ');
    }

    /**
     * Từ payload items (menu_item_id, quantity) trả về chuỗi "Tên x qty, ...".
     */
    protected function getItemNamesFromPayload(array $items): string
    {
        if (empty($items)) {
            return '';
        }
        $ids = array_unique(array_column($items, 'menu_item_id'));
        $namesById = MenuItem::whereIn('id', $ids)->pluck('name', 'id')->map(fn ($n) => trim((string) $n))->toArray();
        $parts = [];
        foreach ($items as $item) {
            $id = $item['menu_item_id'] ?? null;
            $qty = (int) ($item['quantity'] ?? 1);
            $name = $namesById[$id] ?? ('Món #' . $id);
            $parts[] = $name . ' x' . $qty;
        }

        return implode(', ', $parts);
    }
}
