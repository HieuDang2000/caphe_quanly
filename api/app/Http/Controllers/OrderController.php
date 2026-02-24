<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Services\OrderService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class OrderController extends Controller
{
    public function __construct(protected OrderService $orderService) {}

    public function index(Request $request): JsonResponse
    {
        $query = Order::with(['items.menuItem', 'table', 'user', 'customer', 'invoice']);

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }
        // Lọc theo ngày, mặc định hôm nay theo giờ Việt Nam
        $tz = 'Asia/Ho_Chi_Minh';
        $dateStr = $request->get('date', Carbon::now($tz)->toDateString());
        $start = Carbon::parse($dateStr . ' 00:00:00', $tz)->utc();
        $end = Carbon::parse($dateStr . ' 23:59:59.999999', $tz)->utc();
        $query->whereBetween('created_at', [$start, $end]);

        if ($request->has('table_id')) {
            $query->where('table_id', $request->table_id);
        }

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
            'items.*.options' => 'nullable|array',
            'items.*.options.*.id' => 'nullable|exists:menu_item_options,id',
            'notes' => 'nullable|string',
            'discount' => 'nullable|numeric|min:0',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $order = $this->orderService->createOrder($request->all(), auth('api')->id());
        //update order status
        $order->update(['status' => 'in_progress']);

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

        $order = $this->orderService->updateOrder($order, $request->all(), auth('api')->id());
        return response()->json($order);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:pending,in_progress,completed,cancelled,paid',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $order = Order::findOrFail($id);
        $newStatus = $request->status;
        $order->update(['status' => $newStatus]);
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
