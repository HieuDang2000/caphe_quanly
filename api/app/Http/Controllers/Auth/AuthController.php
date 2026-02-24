<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'username' => 'required|string',
            'password' => 'required|string|min:5',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $username = $request->input('username');
        $password = $request->input('password');

        $user = User::where('email', $username)
            ->orWhere('name', $username)
            ->first();

        if (!$user || !Hash::check($password, $user->password)) {
            return response()->json(['message' => 'Tên đăng nhập hoặc mật khẩu không đúng'], 401);
        }

        $token = auth('api')->login($user);

        if (!$token) {
            return response()->json(['message' => 'Email hoặc mật khẩu không đúng'], 401);
        }

        $user = auth('api')->user();
        if (!$user->is_active) {
            auth('api')->logout();
            return response()->json(['message' => 'Tài khoản đã bị khóa'], 403);
        }

        return $this->respondWithToken($token);
    }

    public function register(Request $request): JsonResponse
    {
        $currentUser = auth('api')->user();
        if (!$currentUser->hasRole('admin')) {
            return response()->json(['message' => 'Chỉ admin mới được tạo tài khoản'], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users',
            'password' => 'required|string|min:6',
            'phone' => 'nullable|string|max:20',
            'role_id' => 'required|exists:roles,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => $request->password,
            'phone' => $request->phone,
            'role_id' => $request->role_id,
        ]);

        $user->load('role');

        return response()->json(['message' => 'Tạo tài khoản thành công', 'user' => $user], 201);
    }

    public function me(): JsonResponse
    {
        $user = auth('api')->user();
        $user->load('role');

        return response()->json($user);
    }

    public function logout(): JsonResponse
    {
        auth('api')->logout();

        return response()->json(['message' => 'Đăng xuất thành công']);
    }

    public function refresh(): JsonResponse
    {
        $token = auth('api')->refresh();

        return $this->respondWithToken($token);
    }

    protected function respondWithToken(string $token): JsonResponse
    {
        $user = auth('api')->user();
        $user->load('role');

        return response()->json([
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => auth('api')->factory()->getTTL() * 60,
            'user' => $user,
        ]);
    }
}
