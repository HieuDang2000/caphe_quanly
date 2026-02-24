<?php

use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\CustomerController;
use App\Http\Controllers\InventoryController;
use App\Http\Controllers\InvoiceController;
use App\Http\Controllers\LayoutController;
use App\Http\Controllers\MenuController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\ReservationController;
use App\Http\Controllers\StaffController;
use App\Http\Controllers\UserController;
use Illuminate\Support\Facades\Route;

// Auth
Route::prefix('auth')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
    Route::middleware('auth:api')->group(function () {
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/refresh', [AuthController::class, 'refresh']);
    });
});

Route::middleware('auth:api')->group(function () {
    // Users (admin only)
    Route::middleware('role:admin')->prefix('users')->group(function () {
        Route::get('/', [UserController::class, 'index']);
        Route::get('/{id}', [UserController::class, 'show']);
        Route::put('/{id}', [UserController::class, 'update']);
        Route::put('/{id}/role', [UserController::class, 'updateRole']);
        Route::delete('/{id}', [UserController::class, 'destroy']);
    });

    // Layout
    Route::prefix('layout')->group(function () {
        Route::get('/floors', [LayoutController::class, 'floors']);
        Route::get('/tables', [LayoutController::class, 'tables']);
        Route::get('/floors/{id}/objects', [LayoutController::class, 'floorObjects']);
        Route::middleware('role:admin,manager')->group(function () {
            Route::post('/floors', [LayoutController::class, 'storeFloor']);
            Route::put('/floors/{id}', [LayoutController::class, 'updateFloor']);
            Route::delete('/floors/{id}', [LayoutController::class, 'destroyFloor']);
            Route::post('/objects', [LayoutController::class, 'storeObject']);
            Route::put('/objects/batch', [LayoutController::class, 'batchUpdate']);
            Route::put('/objects/{id}', [LayoutController::class, 'updateObject']);
            Route::delete('/objects/{id}', [LayoutController::class, 'destroyObject']);
        });
    });

    // Menu
    Route::prefix('menu')->group(function () {
        Route::get('/categories', [MenuController::class, 'categories']);
        Route::get('/items', [MenuController::class, 'items']);
        Route::middleware('role:admin,manager')->group(function () {
            Route::post('/categories', [MenuController::class, 'storeCategory']);
            Route::put('/categories/{id}', [MenuController::class, 'updateCategory']);
            Route::delete('/categories/{id}', [MenuController::class, 'destroyCategory']);
            Route::post('/items', [MenuController::class, 'storeItem']);
            Route::put('/items/{id}', [MenuController::class, 'updateItem']);
            Route::delete('/items/{id}', [MenuController::class, 'destroyItem']);
            Route::post('/items/{id}/image', [MenuController::class, 'uploadImage']);
        });
    });

    // Orders
    Route::prefix('orders')->group(function () {
        Route::get('/', [OrderController::class, 'index']);
        Route::post('/', [OrderController::class, 'store']);
        Route::get('/active', [OrderController::class, 'active']);
        Route::get('/{id}', [OrderController::class, 'show']);
        Route::put('/{id}', [OrderController::class, 'update']);
        Route::put('/{id}/status', [OrderController::class, 'updateStatus']);
        Route::get('/table/{tableId}', [OrderController::class, 'tableOrders']);
    });

    // Invoices
    Route::prefix('invoices')->group(function () {
        Route::post('/generate/{orderId}', [InvoiceController::class, 'generate']);
        Route::get('/{id}', [InvoiceController::class, 'show']);
        Route::get('/{id}/pdf', [InvoiceController::class, 'pdf']);
        Route::post('/{id}/payment', [InvoiceController::class, 'addPayment']);
    });

    // Reports
    Route::middleware('role:admin,manager,cashier')->prefix('reports')->group(function () {
        Route::get('/sales', [ReportController::class, 'sales']);
        Route::get('/top-items', [ReportController::class, 'topItems']);
        Route::get('/category-revenue', [ReportController::class, 'categoryRevenue']);
        Route::get('/table-usage', [ReportController::class, 'tableUsage']);
        Route::get('/daily-summary', [ReportController::class, 'dailySummary']);
    });

    // Staff (Phase 2)
    Route::prefix('staff')->group(function () {
        Route::get('/shifts', [StaffController::class, 'shifts']);
        Route::get('/attendances', [StaffController::class, 'attendances']);
        Route::post('/check-in', [StaffController::class, 'checkIn']);
        Route::post('/check-out', [StaffController::class, 'checkOut']);

        Route::middleware('role:admin,manager')->group(function () {
            Route::get('/', [StaffController::class, 'index']);
            Route::get('/{id}', [StaffController::class, 'show'])->where('id', '[0-9]+');
            Route::put('/{id}/profile', [StaffController::class, 'updateProfile'])->where('id', '[0-9]+');
            Route::post('/shifts', [StaffController::class, 'storeShift']);
            Route::put('/shifts/{id}', [StaffController::class, 'updateShift']);
            Route::delete('/shifts/{id}', [StaffController::class, 'deleteShift']);
        });
    });

    // Inventory (Phase 2)
    Route::middleware('role:admin,manager')->prefix('inventory')->group(function () {
        Route::get('/', [InventoryController::class, 'index']);
        Route::post('/', [InventoryController::class, 'store']);
        Route::get('/low-stock', [InventoryController::class, 'lowStock']);
        Route::get('/{id}', [InventoryController::class, 'show']);
        Route::put('/{id}', [InventoryController::class, 'update']);
        Route::delete('/{id}', [InventoryController::class, 'destroy']);
        Route::post('/transactions', [InventoryController::class, 'addTransaction']);
        Route::get('/{itemId}/transactions', [InventoryController::class, 'transactions']);
    });

    // Customers (Phase 2)
    Route::prefix('customers')->group(function () {
        Route::get('/', [CustomerController::class, 'index']);
        Route::post('/', [CustomerController::class, 'store']);
        Route::get('/{id}', [CustomerController::class, 'show']);
        Route::put('/{id}', [CustomerController::class, 'update']);
        Route::delete('/{id}', [CustomerController::class, 'destroy']);
        Route::post('/{id}/points', [CustomerController::class, 'addPoints']);
        Route::post('/{id}/redeem', [CustomerController::class, 'redeemPoints']);
        Route::get('/{id}/points-history', [CustomerController::class, 'pointsHistory']);
    });

    // Reservations (Phase 2)
    Route::prefix('reservations')->group(function () {
        Route::get('/', [ReservationController::class, 'index']);
        Route::post('/', [ReservationController::class, 'store']);
        Route::get('/availability', [ReservationController::class, 'tableAvailability']);
        Route::get('/{id}', [ReservationController::class, 'show']);
        Route::put('/{id}', [ReservationController::class, 'update']);
        Route::put('/{id}/status', [ReservationController::class, 'updateStatus']);
        Route::delete('/{id}', [ReservationController::class, 'destroy']);
    });
});
