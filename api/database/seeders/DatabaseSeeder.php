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

        User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin', 'role_id' => $admin->id, 'phone' => '0901000001']);
        User::create(['name' => 'Quản lý', 'email' => 'manager', 'password' => 'manager', 'role_id' => $manager->id, 'phone' => '0901000002']);
        User::create(['name' => 'Nhân viên A', 'email' => 'staff', 'password' => 'staff', 'role_id' => $staff->id, 'phone' => '0901000003']);
        User::create(['name' => 'Thu ngân', 'email' => 'cashier', 'password' => 'cashier', 'role_id' => $cashier->id, 'phone' => '0901000004']);

        // Floors & Tables
        $floor1 = Floor::create(['name' => 'Tầng trệt', 'floor_number' => 1]);
        $floor2 = Floor::create(['name' => 'Tầng lầu', 'floor_number' => 2]);

        for ($i = 1; $i <= 8; $i++) {
            LayoutObject::create([
                'floor_id' => $floor1->id,
                'type' => 'table',
                'name' => "Bàn $i",
                'position_x' => (($i - 1) % 4) * 150 + 50,
                'position_y' => (int) (($i - 1) / 4) * 150 + 50,
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
                'position_y' => (int) (($i - 9) / 3) * 180 + 50,
                'width' => 100,
                'height' => 100,
                'properties' => ['seats' => 6, 'shape' => 'round'],
            ]);
        }

        // Categories & Menu Items
        $coffee = Category::create(['name' => 'Cà phê', 'sort_order' => 1]);
        $hotDrinks = Category::create(['name' => 'Món nóng', 'sort_order' => 2]);
        $yogurtBlended = Category::create(['name' => 'Sữa chua & Đá xay', 'sort_order' => 3]);
        $milkTea = Category::create(['name' => 'Trà sữa', 'sort_order' => 4]);
        $fruitTea = Category::create(['name' => 'Trà trái cây', 'sort_order' => 5]);
        $snacks = Category::create(['name' => 'Ăn vặt', 'sort_order' => 6]);

        // Danh mục Cà phê
        $coffeeItems = [
            ['name' => 'Cà phê đen phin', 'price' => 13000],
            ['name' => 'Cà phê sữa phin', 'price' => 15000],
            ['name' => 'Cà phê đen ép máy', 'price' => 16000],
            ['name' => 'Cà phê sữa ép máy', 'price' => 18000],
            ['name' => 'Cà phê muối', 'price' => 18000],
            ['name' => 'Cà phê kem trứng', 'price' => 20000],
            ['name' => 'Cà phê cốt dừa', 'price' => 20000],
            ['name' => 'Bạc xỉu', 'price' => 22000],
            ['name' => 'Cacao đá', 'price' => 25000],
        ];
        foreach ($coffeeItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $coffee->id, 'sort_order' => $idx + 1]));
        }

        // Danh mục Món nóng
        $hotDrinkItems = [
            ['name' => 'Sữa nóng', 'price' => 18000],
            ['name' => 'Bạc xỉu nóng', 'price' => 22000],
            ['name' => 'Cacao nóng', 'price' => 25000],
            ['name' => 'Trà gừng mật ong', 'price' => 18000],
        ];
        foreach ($hotDrinkItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $hotDrinks->id, 'sort_order' => $idx + 1]));
        }

        // Danh mục Sữa chua & Đá xay
        $yogurtBlendedItems = [
            ['name' => 'Sữa chua đá xay ', 'price' => 28000],
            ['name' => 'Sữa chua đá xay việt quất', 'price' => 28000],
            ['name' => 'Sữa chua đá xay xoài', 'price' => 28000],
            ['name' => 'Sữa chua đá xay đào', 'price' => 28000],
            ['name' => 'Sữa chua đá xay kiwi', 'price' => 28000],
            ['name' => 'Matcha đá xay', 'price' => 30000],
            ['name' => 'Chocolate đá xay', 'price' => 30000],
        ];
        foreach ($yogurtBlendedItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $yogurtBlended->id, 'sort_order' => $idx + 1]));
        }

        // Danh mục Trà Trái Cây (Fruit Tea)
        $fruitTeaItems = [
            ['name' => 'Trà chanh', 'price' => 15000],
            ['name' => 'Trà chanh hạt chia nha đam', 'price' => 20000],
            ['name' => 'Trà dâu tằm', 'price' => 22000],
            ['name' => 'Trà tắc mật ong nha đam', 'price' => 22000],
            ['name' => 'Trà xoài', 'price' => 25000],
            ['name' => 'Trà đào cam xả', 'price' => 25000],
            ['name' => 'Trà ổi', 'price' => 25000],
            ['name' => 'Trà măng cụt tằm đặc', 'price' => 27000],
            ['name' => 'Trà vải hạt chia', 'price' => 27000],
            ['name' => 'Trà dưa lưới', 'price' => 27000],
            ['name' => 'Trà nho kiwi', 'price' => 27000],
            ['name' => 'Trà trái cây nhiệt đới', 'price' => 30000],
        ];
        foreach ($fruitTeaItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $fruitTea->id, 'sort_order' => $idx + 1]));
        }

        // Danh mục Trà sữa (giá là size M, size L cao hơn)
        $milkTeaItems = [
            ['name' => 'Trà sữa truyền thống', 'price' => 18000],
            ['name' => 'Trà sữa lài', 'price' => 18000],
            ['name' => 'Trà sữa trân châu đường đen', 'price' => 18000],
            ['name' => 'Trà sữa thái xanh matcha', 'price' => 20000],
            ['name' => 'Trà sữa kem machiato', 'price' => 20000],
            ['name' => 'Trà sữa kem trứng vụn dừa', 'price' => 23000],
            ['name' => 'Trà sữa matcha machiato', 'price' => 23000],
            ['name' => 'Trà sữa khoai môn phết', 'price' => 23000],
            ['name' => 'Trà sữa Phô mai phết', 'price' => 23000],
            ['name' => 'Sữa tươi trân châu đường đen', 'price' => 18000],
            ['name' => 'Matcha latte', 'price' => 18000],
        ];
        foreach ($milkTeaItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $milkTea->id, 'sort_order' => $idx + 1]));

            // Menu item options (Size L milk tea)
            $milkTeaItem = MenuItem::where('name', $item['name'])->first();
            if ($milkTeaItem) {
                MenuItemOption::create(['menu_item_id' => $milkTeaItem->id, 'name' => 'Size L', 'extra_price' => 5000]);
            }
        }

        // Danh mục Ăn vặt
        $snackItems = [
            ['name' => 'Combo 5 (Cá / Bò / Tôm / Cá cốm / Cá phô mai)', 'price' => 28000],
            ['name' => 'Combo 7 (Thêm ốc và xúc xích)', 'price' => 38000],
            ['name' => 'Combo 10 (Đầy đủ các loại viên, xúc xích, phô mai que, khoai lang kén, hồ lô...)', 'price' => 48000],
            ['name' => 'Cá viên', 'price' => 10000],
            ['name' => 'Bò viên', 'price' => 10000],
            ['name' => 'Tôm viên', 'price' => 10000],
            ['name' => 'Ốc viên', 'price' => 10000],
            ['name' => 'Phô mai que', 'price' => 10000],
            ['name' => 'Xúc xích', 'price' => 10000],
            ['name' => 'Xúc xích hồ lô', 'price' => 12000],
            ['name' => 'Xúc xích phô mai (Hotdog)', 'price' => 15000],
            ['name' => 'Khoai tây chiên', 'price' => 15000],
            ['name' => 'Khoai lang kén', 'price' => 15000],
            ['name' => 'Cá sốt phô mai', 'price' => 15000],
            ['name' => 'Cá tẩm cốm', 'price' => 15000],
            ['name' => 'Chả cá rau răm', 'price' => 15000],
            ['name' => 'Bánh tráng trộn', 'price' => 15000],
        ];
        foreach ($snackItems as $idx => $item) {
            MenuItem::create(array_merge($item, ['category_id' => $snacks->id, 'sort_order' => $idx + 1]));
        }

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
