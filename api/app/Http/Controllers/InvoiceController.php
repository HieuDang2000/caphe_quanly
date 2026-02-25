<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Models\Order;
use App\Services\InvoiceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Mpdf\Mpdf;

class InvoiceController extends Controller
{
    public function __construct(protected InvoiceService $invoiceService) {}

    public function generate(int $orderId): JsonResponse
    {
        $order = Order::with('items')->findOrFail($orderId);

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
        $invoice->load(['order.items.menuItem', 'order.table', 'order.user', 'order.customer', 'payments']);

        $html = view('invoices.pdf', ['invoice' => $invoice])->render();
        $content = $this->renderPdfWithMpdf($html, [
            'format' => 'A4',
            'margin_left' => 10,
            'margin_right' => 10,
            'margin_top' => 10,
            'margin_bottom' => 10,
            'default_font' => 'dejavusans',
        ]);

        $filename = "hoa-don-{$invoice->invoice_number}.pdf";
        return response($content, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
        ]);
    }

    public function receipt80mm(int $id)
    {
        $invoice = Invoice::findOrFail($id);
        $invoice->load(['order.items.menuItem', 'order.table', 'order.user', 'order.customer']);

        $html = view('invoices.receipt-80mm', ['invoice' => $invoice])->render();
        // 80mm (receipt) - set page width 80mm, height large enough
        $content = $this->renderPdfWithMpdf($html, [
            'format' => [80, 300],
            'margin_left' => 5,
            'margin_right' => 5,
            'margin_top' => 5,
            'margin_bottom' => 5,
            'default_font' => 'dejavusans',
        ]);

        $filename = "hoa-don-{$invoice->invoice_number}-80mm.pdf";
        return response($content, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
        ]);
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

    private function renderPdfWithMpdf(string $html, array $config): string
    {
        $mpdf = new Mpdf($config);
        $mpdf->WriteHTML($html);
        return $mpdf->Output('', 'S');
    }
}
