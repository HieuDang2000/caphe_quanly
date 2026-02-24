<?php

namespace App\Http\Controllers;

use App\Models\Attendance;
use App\Models\Shift;
use App\Models\StaffProfile;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class StaffController extends Controller
{
    // --- Staff Profiles ---

    public function index(): JsonResponse
    {
        $staff = User::with(['role', 'staffProfile'])
            ->whereHas('role', fn($q) => $q->whereIn('name', ['staff', 'cashier', 'manager']))
            ->get();
        return response()->json($staff);
    }

    public function show(int $id): JsonResponse
    {
        $user = User::with(['role', 'staffProfile', 'shifts', 'attendances'])->findOrFail($id);
        return response()->json($user);
    }

    public function updateProfile(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'position' => 'nullable|string|max:255',
            'salary' => 'nullable|numeric|min:0',
            'hire_date' => 'nullable|date',
            'address' => 'nullable|string',
            'emergency_contact' => 'nullable|string|max:255',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $profile = StaffProfile::updateOrCreate(
            ['user_id' => $id],
            $request->only(['position', 'salary', 'hire_date', 'address', 'emergency_contact'])
        );

        return response()->json($profile);
    }

    // --- Shifts ---

    public function shifts(Request $request): JsonResponse
    {
        $query = Shift::with('user');
        if ($request->has('user_id')) $query->where('user_id', $request->user_id);
        if ($request->has('date')) $query->where('shift_date', $request->date);
        if ($request->has('from') && $request->has('to')) {
            $query->whereBetween('shift_date', [$request->from, $request->to]);
        }
        return response()->json($query->orderBy('shift_date')->orderBy('start_time')->get());
    }

    public function storeShift(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'shift_date' => 'required|date',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
        ]);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $shift = Shift::create($request->only(['user_id', 'shift_date', 'start_time', 'end_time']));
        $shift->load('user');

        return response()->json($shift, 201);
    }

    public function updateShift(Request $request, int $id): JsonResponse
    {
        $shift = Shift::findOrFail($id);
        $shift->update($request->only(['shift_date', 'start_time', 'end_time', 'status']));
        return response()->json($shift);
    }

    public function deleteShift(int $id): JsonResponse
    {
        Shift::findOrFail($id)->delete();
        return response()->json(['message' => 'Xóa ca thành công']);
    }

    // --- Attendance ---

    public function attendances(Request $request): JsonResponse
    {
        $query = Attendance::with(['user', 'shift']);
        if ($request->has('user_id')) $query->where('user_id', $request->user_id);
        if ($request->has('date')) $query->whereDate('check_in', $request->date);
        return response()->json($query->orderByDesc('check_in')->get());
    }

    public function checkIn(Request $request): JsonResponse
    {
        $userId = $request->get('user_id', auth('api')->id());
        $today = today();

        $existing = Attendance::where('user_id', $userId)
            ->whereDate('check_in', $today)
            ->whereNull('check_out')
            ->first();

        if ($existing) {
            return response()->json(['message' => 'Đã check-in hôm nay rồi'], 400);
        }

        $shift = Shift::where('user_id', $userId)->where('shift_date', $today)->first();

        $attendance = Attendance::create([
            'user_id' => $userId,
            'shift_id' => $shift?->id,
            'check_in' => now(),
        ]);

        return response()->json($attendance, 201);
    }

    public function checkOut(Request $request): JsonResponse
    {
        $userId = $request->get('user_id', auth('api')->id());

        $attendance = Attendance::where('user_id', $userId)
            ->whereNull('check_out')
            ->latest('check_in')
            ->first();

        if (!$attendance) {
            return response()->json(['message' => 'Chưa check-in'], 400);
        }

        $attendance->update(['check_out' => now()]);

        return response()->json($attendance);
    }
}
