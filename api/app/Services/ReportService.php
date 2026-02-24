<?php

namespace App\Services;

use App\Models\Invoice;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Support\Facades\DB;

class ReportService
{
    public function salesReport(string $from, string $to): array
    {
        $orders = Order::where('status', 'completed')
            ->whereBetween('created_at', [$from, $to . ' 23:59:59'])
            ->get();

        $dailySales = Order::where('status', 'completed')
            ->whereBetween('created_at', [$from, $to . ' 23:59:59'])
            ->select(DB::raw('DATE(created_at) as date'), DB::raw('SUM(total) as revenue'), DB::raw('COUNT(*) as orders_count'))
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        return [
            'total_revenue' => $orders->sum('total'),
            'total_orders' => $orders->count(),
            'average_order' => $orders->count() > 0 ? round($orders->sum('total') / $orders->count()) : 0,
            'daily_sales' => $dailySales,
        ];
    }

    public function topItems(string $from, string $to, int $limit = 10): array
    {
        return OrderItem::join('orders', 'order_items.order_id', '=', 'orders.id')
            ->join('menu_items', 'order_items.menu_item_id', '=', 'menu_items.id')
            ->where('orders.status', 'completed')
            ->whereBetween('orders.created_at', [$from, $to . ' 23:59:59'])
            ->select(
                'menu_items.id',
                'menu_items.name',
                DB::raw('SUM(order_items.quantity) as total_quantity'),
                DB::raw('SUM(order_items.subtotal) as total_revenue')
            )
            ->groupBy('menu_items.id', 'menu_items.name')
            ->orderByDesc('total_quantity')
            ->limit($limit)
            ->get()
            ->toArray();
    }

    public function categoryRevenue(string $from, string $to): array
    {
        return OrderItem::join('orders', 'order_items.order_id', '=', 'orders.id')
            ->join('menu_items', 'order_items.menu_item_id', '=', 'menu_items.id')
            ->join('categories', 'menu_items.category_id', '=', 'categories.id')
            ->where('orders.status', 'completed')
            ->whereBetween('orders.created_at', [$from, $to . ' 23:59:59'])
            ->select(
                'categories.id',
                'categories.name',
                DB::raw('SUM(order_items.subtotal) as revenue'),
                DB::raw('COUNT(DISTINCT orders.id) as orders_count')
            )
            ->groupBy('categories.id', 'categories.name')
            ->orderByDesc('revenue')
            ->get()
            ->toArray();
    }

    public function tableUsage(string $from, string $to): array
    {
        return Order::join('layout_objects', 'orders.table_id', '=', 'layout_objects.id')
            ->where('orders.status', 'completed')
            ->whereBetween('orders.created_at', [$from, $to . ' 23:59:59'])
            ->select(
                'layout_objects.id',
                'layout_objects.name',
                DB::raw('COUNT(*) as usage_count'),
                DB::raw('SUM(orders.total) as revenue')
            )
            ->groupBy('layout_objects.id', 'layout_objects.name')
            ->orderByDesc('usage_count')
            ->get()
            ->toArray();
    }

    public function dailySummary(): array
    {
        $today = today();
        $orders = Order::whereDate('created_at', $today)->get();
        $completed = $orders->where('status', 'completed');
        $invoicesPaid = Invoice::whereDate('created_at', $today)->where('payment_status', 'paid')->sum('total');

        return [
            'date' => $today->format('Y-m-d'),
            'total_orders' => $orders->count(),
            'completed_orders' => $completed->count(),
            'pending_orders' => $orders->where('status', 'pending')->count(),
            'total_revenue' => $completed->sum('total'),
            'total_collected' => $invoicesPaid,
        ];
    }
}
