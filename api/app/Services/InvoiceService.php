<?php

namespace App\Services;

use App\Models\Invoice;
use App\Models\Order;
use App\Models\Payment;

class InvoiceService
{
    public function generate(Order $order): Invoice
    {
        if ($order->invoice) {
            return $order->invoice;
        }

        $subtotal = $order->subtotal;
        $taxRate = 0;
        $taxAmount = 0;
        $discountAmount = $order->discount;
        $total = $subtotal - $discountAmount;

        $invoice = Invoice::create([
            'order_id' => $order->id,
            'invoice_number' => $this->generateInvoiceNumber(),
            'subtotal' => $subtotal,
            'tax_rate' => $taxRate,
            'tax_amount' => $taxAmount,
            'discount_amount' => $discountAmount,
            'total' => $total,
        ]);

        $invoice->load(['order.items.menuItem', 'order.table', 'order.user', 'payments']);

        return $invoice;
    }

    public function addPayment(Invoice $invoice, array $data): Payment
    {
        $payment = Payment::create([
            'invoice_id' => $invoice->id,
            'amount' => $data['amount'],
            'payment_method' => $data['payment_method'] ?? 'cash',
            'reference_number' => $data['reference_number'] ?? null,
            'paid_at' => now(),
        ]);

        $totalPaid = $invoice->totalPaid();
        if ($totalPaid >= $invoice->total) {
            $invoice->update(['payment_status' => 'paid']);
            $invoice->order?->update(['status' => 'paid']);
        } elseif ($totalPaid > 0) {
            $invoice->update(['payment_status' => 'partial']);
        }

        return $payment;
    }

    protected function generateInvoiceNumber(): string
    {
        $date = now()->format('Ymd');
        $count = Invoice::whereDate('created_at', today())->count() + 1;
        return "INV-{$date}-" . str_pad($count, 4, '0', STR_PAD_LEFT);
    }
}
