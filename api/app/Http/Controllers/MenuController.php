<?php

namespace App\Http\Controllers;

use App\Models\Category;
use App\Models\MenuItem;
use App\Models\MenuItemOption;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

class MenuController extends Controller
{
    // --- Categories ---

    public function categories(): JsonResponse
    {
        $categories = Category::withCount('menuItems')->orderBy('sort_order')->get();
        return response()->json($categories);
    }

    public function storeCategory(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'sort_order' => 'integer',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $category = Category::create($request->only(['name', 'description', 'sort_order']));
        return response()->json($category, 201);
    }

    public function updateCategory(Request $request, int $id): JsonResponse
    {
        $category = Category::findOrFail($id);
        $category->update($request->only(['name', 'description', 'sort_order', 'is_active']));
        return response()->json($category);
    }

    public function destroyCategory(int $id): JsonResponse
    {
        Category::findOrFail($id)->delete();
        return response()->json(['message' => 'Xóa danh mục thành công']);
    }

    // --- Menu Items ---

    public function items(Request $request): JsonResponse
    {
        $query = MenuItem::with(['category', 'options']);
        if ($request->has('category_id')) {
            $query->where('category_id', $request->category_id);
        }
        if ($request->has('available')) {
            $query->where('is_available', $request->boolean('available'));
        }
        $items = $query->orderBy('sort_order')->get();
        return response()->json($items);
    }

    public function storeItem(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'category_id' => 'required|exists:categories,id',
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'description' => 'nullable|string',
            'sort_order' => 'integer',
            'options' => 'nullable|array',
            'options.*.name' => 'required_with:options|string|max:255',
            'options.*.extra_price' => 'required_with:options|numeric|min:0',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $item = MenuItem::create($request->only(['category_id', 'name', 'price', 'description', 'sort_order']));
        $this->syncMenuItemOptions($item, $request->input('options', []));
        $item->load(['category', 'options']);
        return response()->json($item, 201);
    }

    public function updateItem(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'options' => 'nullable|array',
            'options.*.name' => 'required_with:options|string|max:255',
            'options.*.extra_price' => 'required_with:options|numeric|min:0',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $item = MenuItem::findOrFail($id);
        $item->update($request->only(['category_id', 'name', 'price', 'description', 'is_available', 'sort_order']));
        if ($request->has('options')) {
            $this->syncMenuItemOptions($item, $request->input('options', []));
        }
        $item->load(['category', 'options']);
        return response()->json($item);
    }

    public function destroyItem(int $id): JsonResponse
    {
        MenuItem::findOrFail($id)->delete();
        return response()->json(['message' => 'Xóa món thành công']);
    }

    public function uploadImage(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'image' => 'required|image|mimes:jpeg,png,jpg,webp|max:2048',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $item = MenuItem::findOrFail($id);

        if ($item->image) {
            Storage::disk('public')->delete($item->image);
        }

        $path = $request->file('image')->store('menu-items', 'public');
        $item->update(['image' => $path]);

        return response()->json(['image' => $path, 'url' => Storage::disk('public')->url($path)]);
    }

    protected function syncMenuItemOptions(MenuItem $item, array $optionsRaw): void
    {
        $item->options()->delete();
        foreach ($optionsRaw as $opt) {
            MenuItemOption::create([
                'menu_item_id' => $item->id,
                'name' => $opt['name'],
                'extra_price' => $opt['extra_price'] ?? 0,
            ]);
        }
    }
}
