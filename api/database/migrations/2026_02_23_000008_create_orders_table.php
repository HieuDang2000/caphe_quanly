<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->foreignId('table_id')->nullable()->constrained('layout_objects')->nullOnDelete();
            $table->string('order_number')->unique();
            $table->string('status')->default('pending'); // pending, in_progress, completed, cancelled
            $table->decimal('subtotal', 12, 0)->default(0);
            $table->decimal('tax', 12, 0)->default(0);
            $table->decimal('discount', 12, 0)->default(0);
            $table->decimal('total', 12, 0)->default(0);
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
