<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: DejaVu Sans, sans-serif; font-size: 12px; color: #333; }
        .header { text-align: center; margin-bottom: 20px; border-bottom: 2px solid #6F4E37; padding-bottom: 10px; }
        .header h1 { color: #6F4E37; margin: 0; font-size: 24px; }
        .header p { margin: 2px 0; color: #666; }
        .info { margin-bottom: 15px; }
        .info table { width: 100%; }
        .info td { padding: 3px 0; }
        .items { width: 100%; border-collapse: collapse; margin-bottom: 15px; }
        .items th { background: #6F4E37; color: white; padding: 8px; text-align: left; }
        .items td { padding: 8px; border-bottom: 1px solid #eee; }
        .items tr:nth-child(even) { background: #f9f9f9; }
        .totals { float: right; width: 250px; }
        .totals table { width: 100%; }
        .totals td { padding: 4px 8px; }
        .totals .total-row { font-weight: bold; font-size: 16px; border-top: 2px solid #6F4E37; color: #6F4E37; }
        .footer { text-align: center; margin-top: 30px; color: #999; font-size: 10px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>COFFEE SHOP</h1>
        <p>Hóa đơn thanh toán</p>
    </div>

    <div class="info">
        <table>
            <tr>
                <td><strong>Số HĐ:</strong> {{ $invoice->invoice_number }}</td>
                <td style="text-align:right"><strong>Ngày:</strong> {{ $invoice->created_at->format('d/m/Y H:i') }}</td>
            </tr>
            <tr>
                <td><strong>Đơn hàng:</strong> {{ $invoice->order->order_number }}</td>
                <td style="text-align:right"><strong>NV:</strong> {{ $invoice->order->user->name }}</td>
            </tr>
            @if($invoice->order->table)
            <tr>
                <td><strong>Bàn:</strong> {{ $invoice->order->table->name }}</td>
                <td></td>
            </tr>
            @endif
            @if($invoice->order->customer)
            <tr>
                <td><strong>Khách:</strong> {{ $invoice->order->customer->name }}</td>
                <td style="text-align:right"><strong>SĐT:</strong> {{ $invoice->order->customer->phone }}</td>
            </tr>
            @endif
        </table>
    </div>

    <table class="items">
        <thead>
            <tr>
                <th>#</th>
                <th>Món</th>
                <th style="text-align:center">SL</th>
                <th style="text-align:right">Đơn giá</th>
                <th style="text-align:right">Thành tiền</th>
            </tr>
        </thead>
        <tbody>
            @foreach($invoice->order->items as $idx => $item)
            <tr>
                <td>{{ $idx + 1 }}</td>
                <td>{{ $item->menuItem->name }}</td>
                <td style="text-align:center">{{ $item->quantity }}</td>
                <td style="text-align:right">{{ number_format($item->unit_price, 0, ',', '.') }}đ</td>
                <td style="text-align:right">{{ number_format($item->subtotal, 0, ',', '.') }}đ</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="totals">
        <table>
            <tr>
                <td>Tạm tính:</td>
                <td style="text-align:right">{{ number_format($invoice->subtotal, 0, ',', '.') }}đ</td>
            </tr>
            <tr>
                <td>VAT ({{ $invoice->tax_rate }}%):</td>
                <td style="text-align:right">{{ number_format($invoice->tax_amount, 0, ',', '.') }}đ</td>
            </tr>
            @if($invoice->discount_amount > 0)
            <tr>
                <td>Giảm giá:</td>
                <td style="text-align:right">-{{ number_format($invoice->discount_amount, 0, ',', '.') }}đ</td>
            </tr>
            @endif
            <tr class="total-row">
                <td>Tổng cộng:</td>
                <td style="text-align:right">{{ number_format($invoice->total, 0, ',', '.') }}đ</td>
            </tr>
        </table>
    </div>

    <div style="clear:both"></div>

    <div class="footer">
        <p>Cảm ơn quý khách! Hẹn gặp lại!</p>
    </div>
</body>
</html>
