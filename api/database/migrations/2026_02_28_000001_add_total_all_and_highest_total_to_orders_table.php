<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (!Schema::hasColumn('orders', 'total_all')) {
                $table->decimal('total_all', 12, 0)->default(0)->after('total');
            }
            if (!Schema::hasColumn('orders', 'highest_total')) {
                $table->decimal('highest_total', 12, 0)->nullable()->after('total_all');
            }
        });

        $driver = Schema::getConnection()->getDriverName();
        if ($driver === 'sqlite') {
            DB::statement('UPDATE orders SET total_all = (SELECT COALESCE(SUM(subtotal), 0) FROM order_items WHERE order_items.order_id = orders.id) - COALESCE(orders.discount, 0)');
        }
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['total_all', 'highest_total']);
        });
    }
};
