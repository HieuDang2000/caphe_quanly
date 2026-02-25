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
        if ($order->status === 'paid') {
            return response()->json(['message' => 'Không thể sửa đơn đã thanh toán'], 400);
        }

        $order = $this->orderService->updateOrder($order, $request->all(), auth('api')->id());
        return response()->json($order);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:pending,paid',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $order = Order::findOrFail($id);
        $newStatus = $request->status;
        $order->update(['status' => $newStatus]);

        // Chỉ reset is_paid khi đưa đơn về trạng thái pending.
        // Khi thanh toán toàn bộ (status = paid) thì không thay đổi is_paid
        // để vẫn phân biệt được các item đã được thanh toán theo kiểu "một phần".
        if ($newStatus === 'pending') {
            $order->items()->update(['is_paid' => false]);
        }

        $order->load(['items.menuItem', 'table', 'user']);

        return response()->json($order);
    }

    public function payItems(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'item_ids' => 'required|array|min:1',
            'item_ids.*' => 'required|integer|exists:order_items,id',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $order = Order::with('items')->findOrFail($id);

        // Chỉ cập nhật các item thuộc đơn này
        $order->items()
            ->whereIn('id', $request->input('item_ids', []))
            ->update(['is_paid' => true]);
        
        $order->total -= $order->items()->whereIn('id', $request->input('item_ids', []))->sum('subtotal');
        $order->save();

        $order->refresh()->load(['items.menuItem', 'table', 'user']);

        if ($order->items->every(fn ($item) => $item->is_paid)) {
            $order->update(['status' => 'paid']);
        }

        return response()->json($order);
    }

    public function tableOrders(int $tableId): JsonResponse
    {
        $orders = Order::with(['items.menuItem', 'user'])
            ->where('table_id', $tableId)
            ->where('status', 'pending')
            ->orderByDesc('created_at')
            ->get();

        return response()->json($orders);
    }

    public function active(): JsonResponse
    {
        $orders = Order::with(['items.menuItem', 'table', 'user'])
            ->where('status', 'pending')
            ->orderByDesc('created_at')
            ->get();

        return response()->json($orders);
    }

    /**
     * Trả về danh sách bàn đang có đơn pending (nhẹ, chỉ theo bàn).
     */
    public function activeTables(): JsonResponse
    {
         $tables = Order::query()
             ->selectRaw('table_id, COUNT(*) as orders_count, MAX(created_at) as latest_order_at')
             ->where('status', 'pending')
             ->whereNotNull('table_id')
             ->groupBy('table_id')
             ->orderByDesc('latest_order_at')
             ->get();

         return response()->json($tables);
    }
}
