<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        @page { size: 80mm auto; margin: 5mm; }
        body { font-family: "DejaVu Sans", sans-serif; font-size: 11px; line-height: 1.4; color: #333; }
        .header { text-align: center; margin-bottom: 8px; }
        .header h1 { margin: 0; font-size: 16px; }
        .header p { margin: 2px 0; }
        .line { border-top: 1px dashed #999; margin: 6px 0; }
        .row { display: flex; justify-content: space-between; }
        .items { width: 100%; margin-top: 4px; }
        .items th, .items td { font-size: 10px; padding: 2px 0; }
        .items th { border-bottom: 1px solid #999; }
        .totals { width: 100%; margin-top: 6px; }
        .totals td { padding: 2px 0; font-size: 11px; }
        .totals .total { font-weight: bold; font-size: 13px; }
        .center { text-align: center; }
    </style>
</head>
<body>
    <div class="header">
        <h1>COFFEE SHOP</h1>
        <p>HÓA ĐƠN THANH TOÁN</p>
    </div>

    <div class="row">
        <span>HĐ: {{ $invoice->invoice_number }}</span>
        <span>{{ $invoice->created_at->format('d/m/Y H:i') }}</span>
    </div>
    <div class="row">
        <span>ĐH: {{ $invoice->order->order_number }}</span>
        <span>NV: {{ $invoice->order->user->name }}</span>
    </div>
    @if($invoice->order->table)
    <div class="row">
        <span>Bàn: {{ $invoice->order->table->name }}</span>
    </div>
    @endif
    @if($invoice->order->customer)
    <div class="row">
        <span>KH: {{ $invoice->order->customer->name }}</span>
        @if($invoice->order->customer->phone)
        <span>{{ $invoice->order->customer->phone }}</span>
        @endif
    </div>
    @endif

    <div class="line"></div>

    <table class="items">
        <thead>
            <tr>
                <th style="width: 40%">Món</th>
                <th style="width: 20%; text-align:center">SL</th>
                <th style="width: 40%; text-align:right">Tiền</th>
            </tr>
        </thead>
        <tbody>
            @foreach($invoice->order->items as $item)
            <tr>
                <td>{{ $item->menuItem->name }}</td>
                <td style="text-align:center">{{ $item->quantity }}</td>
                <td style="text-align:right">{{ number_format($item->subtotal, 0, ',', '.') }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="line"></div>

    <table class="totals">
        <tr>
            <td>Tạm tính</td>
            <td style="text-align:right">{{ number_format($invoice->subtotal, 0, ',', '.') }}</td>
        </tr>
        @if($invoice->discount_amount > 0)
        <tr>
            <td>Giảm giá</td>
            <td style="text-align:right">-{{ number_format($invoice->discount_amount, 0, ',', '.') }}</td>
        </tr>
        @endif
        <tr class="total">
            <td>Tổng cộng</td>
            <td style="text-align:right">{{ number_format($invoice->total, 0, ',', '.') }}</td>
        </tr>
    </table>

    <div class="line"></div>

    <p class="center">Cảm ơn quý khách! Hẹn gặp lại!</p>
</body>
</html>

