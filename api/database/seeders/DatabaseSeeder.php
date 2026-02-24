<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Customer;
use App\Models\Floor;
use App\Models\InventoryItem;
use App\Models\LayoutObject;
use App\Models\MenuItem;
use App\Models\MenuItemOption;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = Role::create(['name' => 'admin', 'display_name' => 'Quản trị viên', 'description' => 'Toàn quyền hệ thống']);
        $manager = Role::create(['name' => 'manager', 'display_name' => 'Quản lý', 'description' => 'Quản lý quán']);
        $staff = Role::create(['name' => 'staff', 'display_name' => 'Nhân viên', 'description' => 'Nhân viên phục vụ']);
        $cashier = Role::create(['name' => 'cashier', 'display_name' => 'Thu ngân', 'description' => 'Thu ngân']);

        User::create(['name' => 'Admin', 'email' => 'admin@coffee.vn', 'password' => 'password', 'role_id' => $admin->id, 'phone' => '0901000001']);
        User::create(['name' => 'Quản lý', 'email' => 'manager@coffee.vn', 'password' => 'password', 'role_id' => $manager->id, 'phone' => '0901000002']);
        User::create(['name' => 'Nhân viên A', 'email' => 'staff@coffee.vn', 'password' => 'password', 'role_id' => $staff->id, 'phone' => '0901000003']);
        User::create(['name' => 'Thu ngân', 'email' => 'cashier@coffee.vn', 'password' => 'password', 'role_id' => $cashier->id, 'phone' => '0901000004']);

        // Floors & Tables
        $floor1 = Floor::create(['name' => 'Tầng trệt', 'floor_number' => 1]);
        $floor2 = Floor::create(['name' => 'Tầng lầu', 'floor_number' => 2]);

        for ($i = 1; $i <= 8; $i++) {
            LayoutObject::create([
                'floor_id' => $floor1->id,
                'type' => 'table',
                'name' => "Bàn $i",
                'position_x' => (($i - 1) % 4) * 150 + 50,
                'position_y' => (int)(($i - 1) / 4) * 150 + 50,
                'width' => 80,
                'height' => 80,
                'properties' => ['seats' => 4, 'shape' => 'square'],
            ]);
        }

        for ($i = 9; $i <= 14; $i++) {
            LayoutObject::create([
                'floor_id' => $floor2->id,
                'type' => 'table',
                'name' => "Bàn $i",
                'position_x' => (($i - 9) % 3) * 180 + 50,
                'position_y' => (int)(($i - 9) / 3) * 180 + 50,
                'width' => 100,
                'height' => 100,
                'properties' => ['seats' => 6, 'shape' => 'round'],
            ]);
        }

        // Categories & Menu Items
        $coffee = Category::create(['name' => 'Cà phê', 'sort_order' => 1]);
        $tea = Category::create(['name' => 'Trà', 'sort_order' => 2]);
        $juice = Category::create(['name' => 'Nước ép', 'sort_order' => 3]);
        $food = Category::create(['name' => 'Đồ ăn nhẹ', 'sort_order' => 4]);

        $coffeeItems = [
            ['name' => 'Cà phê đen', 'price' => 25000],
            ['name' => 'Cà phê sữa', 'price' => 30000],
            ['name' => 'Bạc xỉu', 'price' => 32000],
            ['name' => 'Cappuccino', 'price' => 45000],
            ['name' => 'Latte', 'price' => 45000],
            ['name' => 'Espresso', 'price' => 35000],
            ['name' => 'Americano', 'price' => 40000],
            ['name' => 'Mocha', 'price' => 50000],
        ];
        foreach ($coffeeItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $coffee->id, 'sort_order' => $idx + 1]));
        }

        $teaItems = [
            ['name' => 'Trà đào', 'price' => 35000],
            ['name' => 'Trà vải', 'price' => 35000],
            ['name' => 'Trà chanh', 'price' => 25000],
            ['name' => 'Trà xanh matcha', 'price' => 45000],
            ['name' => 'Trà ô long', 'price' => 30000],
        ];
        foreach ($teaItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $tea->id, 'sort_order' => $idx + 1]));
        }

        $juiceItems = [
            ['name' => 'Nước ép cam', 'price' => 35000],
            ['name' => 'Nước ép dưa hấu', 'price' => 30000],
            ['name' => 'Sinh tố bơ', 'price' => 40000],
            ['name' => 'Sinh tố xoài', 'price' => 38000],
        ];
        foreach ($juiceItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $juice->id, 'sort_order' => $idx + 1]));
        }

        $foodItems = [
            ['name' => 'Bánh mì', 'price' => 25000],
            ['name' => 'Croissant', 'price' => 30000],
            ['name' => 'Bánh flan', 'price' => 20000],
            ['name' => 'Khoai tây chiên', 'price' => 35000],
        ];
        foreach ($foodItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $food->id, 'sort_order' => $idx + 1]));
        }

        // Menu item options (Size L, Trân châu, etc.)
        $traDao = MenuItem::where('name', 'Trà đào')->first();
        if ($traDao) {
            MenuItemOption::create(['menu_item_id' => $traDao->id, 'name' => 'Size L', 'extra_price' => 5000]);
            MenuItemOption::create(['menu_item_id' => $traDao->id, 'name' => 'Trân châu thêm', 'extra_price' => 4000]);
        }
        $caPheSua = MenuItem::where('name', 'Cà phê sữa')->first();
        if ($caPheSua) {
            MenuItemOption::create(['menu_item_id' => $caPheSua->id, 'name' => 'Size L', 'extra_price' => 5000]);
            MenuItemOption::create(['menu_item_id' => $caPheSua->id, 'name' => 'Trân châu thêm', 'extra_price' => 4000]);
        }

        // Sample customers
        Customer::create(['name' => 'Nguyễn Văn A', 'phone' => '0912345678', 'email' => 'nva@email.com', 'points' => 150]);
        Customer::create(['name' => 'Trần Thị B', 'phone' => '0987654321', 'email' => 'ttb@email.com', 'points' => 600, 'tier' => 'silver']);

        // Inventory items
        $inventoryData = [
            ['name' => 'Cà phê hạt', 'unit' => 'kg', 'quantity' => 20, 'min_quantity' => 5, 'cost_per_unit' => 200000],
            ['name' => 'Sữa tươi', 'unit' => 'l', 'quantity' => 30, 'min_quantity' => 10, 'cost_per_unit' => 30000],
            ['name' => 'Đường', 'unit' => 'kg', 'quantity' => 15, 'min_quantity' => 3, 'cost_per_unit' => 20000],
            ['name' => 'Trà ô long', 'unit' => 'kg', 'quantity' => 5, 'min_quantity' => 1, 'cost_per_unit' => 300000],
            ['name' => 'Đào ngâm', 'unit' => 'kg', 'quantity' => 10, 'min_quantity' => 2, 'cost_per_unit' => 60000],
            ['name' => 'Matcha bột', 'unit' => 'kg', 'quantity' => 2, 'min_quantity' => 0.5, 'cost_per_unit' => 500000],
        ];
        foreach ($inventoryData as $item) {
            InventoryItem::create($item);
        }
    }
}
