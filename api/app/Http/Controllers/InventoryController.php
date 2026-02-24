<?php

namespace App\Http\Controllers;

use App\Models\InventoryItem;
use App\Models\InventoryTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class InventoryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = InventoryItem::query();
        if ($request->boolean('low_stock')) {
            $query->whereRaw('quantity <= min_quantity');
        }
        return response()->json($query->orderBy('name')->get());
    }

    public function show(int $id): JsonResponse
    {
        $item = InventoryItem::with(['transactions' => fn($q) => $q->latest()->limit(20), 'transactions.user'])->findOrFail($id);
        return response()->json($item);
    }

    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'unit' => 'required|string|max:20',
            'quantity' => 'numeric|min:0',
            'min_quantity' => 'numeric|min:0',
            'cost_per_unit' => 'numeric|min:0',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $item = InventoryItem::create($request->all());
        return response()->json($item, 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $item = InventoryItem::findOrFail($id);
        $item->update($request->only(['name', 'unit', 'min_quantity', 'cost_per_unit']));
        return response()->json($item);
    }

    public function destroy(int $id): JsonResponse
    {
        InventoryItem::findOrFail($id)->delete();
        return response()->json(['message' => 'Xóa thành công']);
    }

    public function addTransaction(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'inventory_item_id' => 'required|exists:inventory_items,id',
            'type' => 'required|in:in,out,adjust',
            'quantity' => 'required|numeric|min:0.01',
            'reason' => 'nullable|string',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $item = InventoryItem::findOrFail($request->inventory_item_id);

        if ($request->type === 'out' && $item->quantity < $request->quantity) {
            return response()->json(['message' => 'Không đủ số lượng trong kho'], 400);
        }

        $transaction = InventoryTransaction::create([
            'inventory_item_id' => $item->id,
            'type' => $request->type,
            'quantity' => $request->quantity,
            'reason' => $request->reason,
            'user_id' => auth('api')->id(),
        ]);

        match ($request->type) {
            'in' => $item->increment('quantity', $request->quantity),
            'out' => $item->decrement('quantity', $request->quantity),
            'adjust' => $item->update(['quantity' => $request->quantity]),
        };

        $item->refresh();

        return response()->json([
            'transaction' => $transaction,
            'item' => $item,
            'low_stock_warning' => $item->isLowStock(),
        ], 201);
    }

    public function transactions(int $itemId): JsonResponse
    {
        $transactions = InventoryTransaction::with('user')
            ->where('inventory_item_id', $itemId)
            ->orderByDesc('created_at')
            ->paginate(20);

        return response()->json($transactions);
    }

    public function lowStock(): JsonResponse
    {
        $items = InventoryItem::whereRaw('quantity <= min_quantity')->get();
        return response()->json($items);
    }
}
