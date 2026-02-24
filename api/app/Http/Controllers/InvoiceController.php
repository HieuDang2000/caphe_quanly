<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Models\Order;
use App\Services\InvoiceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class InvoiceController extends Controller
{
    public function __construct(protected InvoiceService $invoiceService) {}

    public function generate(int $orderId): JsonResponse
    {
        $order = Order::with('items')->findOrFail($orderId);

        if ($order->status !== 'completed') {
            return response()->json(['message' => 'Chỉ tạo hóa đơn cho đơn hoàn thành'], 400);
        }

        $invoice = $this->invoiceService->generate($order);

        return response()->json($invoice, 201);
    }

    public function show(int $id): JsonResponse
    {
        $invoice = Invoice::with(['order.items.menuItem', 'order.table', 'order.user', 'order.customer', 'payments'])->findOrFail($id);
        return response()->json($invoice);
    }

    public function pdf(int $id)
    {
        $invoice = Invoice::findOrFail($id);
        $pdf = $this->invoiceService->generatePdf($invoice);

        return $pdf->download("hoa-don-{$invoice->invoice_number}.pdf");
    }

    public function addPayment(Request $request, int $id): JsonResponse
    {
        $invoice = Invoice::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'amount' => 'required|numeric|min:1',
            'payment_method' => 'required|in:cash,card,transfer',
            'reference_number' => 'nullable|string',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $payment = $this->invoiceService->addPayment($invoice, $request->all());
        $invoice->refresh()->load('payments');

        return response()->json([
            'payment' => $payment,
            'invoice' => $invoice,
        ]);
    }
}
