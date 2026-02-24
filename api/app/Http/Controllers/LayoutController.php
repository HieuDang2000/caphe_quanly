<?php

namespace App\Http\Controllers;

use App\Models\Floor;
use App\Models\LayoutObject;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class LayoutController extends Controller
{
    // --- Floors ---

    public function floors(): JsonResponse
    {
        $floors = Floor::withCount('layoutObjects')->orderBy('floor_number')->get();
        return response()->json($floors);
    }

    public function storeFloor(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'floor_number' => 'required|integer',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $floor = Floor::create($request->only(['name', 'floor_number']));
        return response()->json($floor, 201);
    }

    public function updateFloor(Request $request, int $id): JsonResponse
    {
        $floor = Floor::findOrFail($id);
        $floor->update($request->only(['name', 'floor_number', 'is_active']));
        return response()->json($floor);
    }

    public function destroyFloor(int $id): JsonResponse
    {
        Floor::findOrFail($id)->delete();
        return response()->json(['message' => 'Xóa tầng thành công']);
    }

    // --- Layout Objects ---

    public function floorObjects(int $floorId): JsonResponse
    {
        $objects = LayoutObject::where('floor_id', $floorId)->get();
        return response()->json($objects);
    }

    public function storeObject(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'floor_id' => 'required|exists:floors,id',
            'type' => 'required|in:table,wall,window,door,reception',
            'name' => 'required|string|max:255',
            'position_x' => 'numeric',
            'position_y' => 'numeric',
            'width' => 'numeric|min:10',
            'height' => 'numeric|min:10',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $object = LayoutObject::create($request->all());
        return response()->json($object, 201);
    }

    public function updateObject(Request $request, int $id): JsonResponse
    {
        $object = LayoutObject::findOrFail($id);
        $object->update($request->all());
        return response()->json($object);
    }

    public function batchUpdate(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'objects' => 'required|array',
            'objects.*.id' => 'required|exists:layout_objects,id',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        foreach ($request->objects as $objData) {
            LayoutObject::where('id', $objData['id'])->update(
                collect($objData)->except('id')->toArray()
            );
        }

        return response()->json(['message' => 'Cập nhật thành công']);
    }

    public function destroyObject(int $id): JsonResponse
    {
        LayoutObject::findOrFail($id)->delete();
        return response()->json(['message' => 'Xóa thành công']);
    }

    public function tables(): JsonResponse
    {
        $tables = LayoutObject::where('type', 'table')
            ->where('is_active', true)
            ->with('activeOrder')
            ->get()
            ->map(function ($table) {
                $table->is_occupied = $table->activeOrder !== null;
                unset($table->activeOrder);
                return $table;
            });

        return response()->json($tables);
    }
}
