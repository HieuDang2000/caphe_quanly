<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('layout_objects', function (Blueprint $table) {
            $table->id();
            $table->foreignId('floor_id')->constrained('floors')->cascadeOnDelete();
            $table->string('type'); // table, wall, window, door, reception
            $table->string('name');
            $table->double('position_x')->default(0);
            $table->double('position_y')->default(0);
            $table->double('width')->default(80);
            $table->double('height')->default(80);
            $table->double('rotation')->default(0);
            $table->json('properties')->nullable(); // seats, shape, color, etc.
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('layout_objects');
    }
};
