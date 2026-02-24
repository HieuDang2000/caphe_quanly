<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class UserController extends Controller
{
    public function index(): JsonResponse
    {
        $users = User::with('role')->orderBy('name')->get();
        return response()->json($users);
    }

    public function show(int $id): JsonResponse
    {
        $user = User::with('role', 'staffProfile')->findOrFail($id);
        return response()->json($user);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $user = User::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255',
            'email' => 'sometimes|email|unique:users,email,' . $id,
            'phone' => 'nullable|string|max:20',
            'is_active' => 'sometimes|boolean',
            'password' => 'nullable|string|min:6',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $data = $request->only(['name', 'email', 'phone', 'is_active']);
        if ($request->filled('password')) {
            $data['password'] = $request->password;
        }

        $user->update($data);
        $user->load('role');

        return response()->json(['message' => 'Cập nhật thành công', 'user' => $user]);
    }

    public function updateRole(Request $request, int $id): JsonResponse
    {
        $user = User::findOrFail($id);
        $validator = Validator::make($request->all(), [
            'role_id' => 'required|exists:roles,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user->update(['role_id' => $request->role_id]);
        $user->load('role');

        return response()->json(['message' => 'Cập nhật vai trò thành công', 'user' => $user]);
    }

    public function destroy(int $id): JsonResponse
    {
        $user = User::findOrFail($id);
        if ($user->id === auth('api')->id()) {
            return response()->json(['message' => 'Không thể xóa tài khoản đang đăng nhập'], 400);
        }
        $user->delete();

        return response()->json(['message' => 'Xóa thành công']);
    }
}
