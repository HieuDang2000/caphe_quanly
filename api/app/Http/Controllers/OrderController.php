<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class OrderController extends Controller
{
    public function __construct(protected OrderService $orderService) {}

    public function index(Request $request): JsonResponse
    {
        $query = Order::with(['items.menuItem', 'table', 'user', 'customer']);

        if ($request->has('status')) $query->where('status', $request->status);
        if ($request->has('date')) $query->whereDate('created_at', $request->date);
        if ($request->has('table_id')) $query->where('table_id', $request->table_id);

        $orders = $query->orderByDesc('created_at')->paginate($request->get('per_page', 20));
        return response()->json($orders);
    }

    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'table_id' => 'nullable|exists:layout_objects,id',
            'customer_id' => 'nullable|exists:customers,id',
            'items' => 'required|array|min:1',
            'items.*.menu_item_id' => 'required|exists:menu_items,id',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.notes' => 'nullable|string',
            'notes' => 'nullable|string',
            'discount' => 'nullable|numeric|min:0',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $order = $this->orderService->createOrder($request->all(), auth('api')->id());
        return response()->json($order, 201);
    }

    public function show(int $id): JsonResponse
    {
        $order = Order::with(['items.menuItem', 'table', 'user', 'customer', 'invoice.payments'])->findOrFail($id);
        return response()->json($order);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $order = Order::findOrFail($id);
        if ($order->status === 'completed' || $order->status === 'cancelled') {
            return response()->json(['message' => 'Không thể sửa đơn hàng đã hoàn thành/hủy'], 400);
        }

        $order = $this->orderService->updateOrder($order, $request->all());
        return response()->json($order);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:pending,in_progress,completed,cancelled',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $order = Order::findOrFail($id);
        $order->update(['status' => $request->status]);
        $order->load(['items.menuItem', 'table', 'user']);

        return response()->json($order);
    }

    public function tableOrders(int $tableId): JsonResponse
    {
        $orders = Order::with(['items.menuItem', 'user'])
            ->where('table_id', $tableId)
            ->whereIn('status', ['pending', 'in_progress'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json($orders);
    }

    public function active(): JsonResponse
    {
        $orders = Order::with(['items.menuItem', 'table', 'user'])
            ->whereIn('status', ['pending', 'in_progress'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json($orders);
    }
}
