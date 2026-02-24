<?php

namespace App\Http\Controllers;

use App\Models\Reservation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ReservationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Reservation::with(['customer', 'table']);

        if ($request->has('date')) $query->where('reservation_date', $request->date);
        if ($request->has('status')) $query->where('status', $request->status);
        if ($request->has('table_id')) $query->where('table_id', $request->table_id);
        if ($request->has('from') && $request->has('to')) {
            $query->whereBetween('reservation_date', [$request->from, $request->to]);
        }

        return response()->json($query->orderBy('reservation_date')->orderBy('start_time')->get());
    }

    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'customer_id' => 'required|exists:customers,id',
            'table_id' => 'required|exists:layout_objects,id',
            'reservation_date' => 'required|date|after_or_equal:today',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
            'guests_count' => 'required|integer|min:1',
            'notes' => 'nullable|string',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $conflict = Reservation::where('table_id', $request->table_id)
            ->where('reservation_date', $request->reservation_date)
            ->where('status', '!=', 'cancelled')
            ->where(function ($q) use ($request) {
                $q->whereBetween('start_time', [$request->start_time, $request->end_time])
                  ->orWhereBetween('end_time', [$request->start_time, $request->end_time])
                  ->orWhere(function ($q2) use ($request) {
                      $q2->where('start_time', '<=', $request->start_time)
                          ->where('end_time', '>=', $request->end_time);
                  });
            })
            ->exists();

        if ($conflict) {
            return response()->json(['message' => 'Bàn đã được đặt trong khung giờ này'], 409);
        }

        $reservation = Reservation::create($request->all());
        $reservation->load(['customer', 'table']);

        return response()->json($reservation, 201);
    }

    public function show(int $id): JsonResponse
    {
        $reservation = Reservation::with(['customer', 'table'])->findOrFail($id);
        return response()->json($reservation);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $reservation = Reservation::findOrFail($id);
        $reservation->update($request->only([
            'reservation_date', 'start_time', 'end_time', 'guests_count', 'status', 'notes',
        ]));
        $reservation->load(['customer', 'table']);
        return response()->json($reservation);
    }

    public function destroy(int $id): JsonResponse
    {
        Reservation::findOrFail($id)->delete();
        return response()->json(['message' => 'Xóa đặt bàn thành công']);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:pending,confirmed,cancelled,completed',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $reservation = Reservation::findOrFail($id);
        $reservation->update(['status' => $request->status]);

        return response()->json($reservation);
    }

    public function tableAvailability(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'date' => 'required|date',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $bookedTableIds = Reservation::where('reservation_date', $request->date)
            ->where('status', '!=', 'cancelled')
            ->where(function ($q) use ($request) {
                $q->whereBetween('start_time', [$request->start_time, $request->end_time])
                  ->orWhereBetween('end_time', [$request->start_time, $request->end_time]);
            })
            ->pluck('table_id');

        return response()->json(['booked_table_ids' => $bookedTableIds]);
    }
}
