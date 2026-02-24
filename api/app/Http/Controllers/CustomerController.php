<?php

namespace App\Http\Controllers;

use App\Models\Customer;
use App\Models\CustomerPoint;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Customer::query();
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%");
            });
        }
        if ($request->has('tier')) $query->where('tier', $request->tier);

        return response()->json($query->orderBy('name')->get());
    }

    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'phone' => 'nullable|string|unique:customers,phone',
            'email' => 'nullable|email',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $customer = Customer::create($request->only(['name', 'phone', 'email']));
        return response()->json($customer, 201);
    }

    public function show(int $id): JsonResponse
    {
        $customer = Customer::with(['pointsHistory' => fn($q) => $q->latest()->limit(20)])->findOrFail($id);
        return response()->json($customer);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $customer = Customer::findOrFail($id);
        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255',
            'phone' => 'nullable|string|unique:customers,phone,' . $id,
            'email' => 'nullable|email',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $customer->update($request->only(['name', 'phone', 'email']));
        return response()->json($customer);
    }

    public function destroy(int $id): JsonResponse
    {
        Customer::findOrFail($id)->delete();
        return response()->json(['message' => 'Xóa thành công']);
    }

    public function addPoints(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'points' => 'required|integer|min:1',
            'order_id' => 'nullable|exists:orders,id',
            'description' => 'nullable|string',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $customer = Customer::findOrFail($id);

        CustomerPoint::create([
            'customer_id' => $id,
            'order_id' => $request->order_id,
            'points' => $request->points,
            'type' => 'earn',
            'description' => $request->description ?? 'Tích điểm',
        ]);

        $customer->increment('points', $request->points);
        $customer->updateTier();

        return response()->json($customer);
    }

    public function redeemPoints(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'points' => 'required|integer|min:1',
            'description' => 'nullable|string',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $customer = Customer::findOrFail($id);
        if ($customer->points < $request->points) {
            return response()->json(['message' => 'Không đủ điểm'], 400);
        }

        CustomerPoint::create([
            'customer_id' => $id,
            'points' => -$request->points,
            'type' => 'redeem',
            'description' => $request->description ?? 'Đổi điểm',
        ]);

        $customer->decrement('points', $request->points);
        $customer->updateTier();

        return response()->json($customer);
    }

    public function pointsHistory(int $id): JsonResponse
    {
        $history = CustomerPoint::where('customer_id', $id)->orderByDesc('created_at')->paginate(20);
        return response()->json($history);
    }
}
