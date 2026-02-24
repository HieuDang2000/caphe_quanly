<?php

namespace App\Http\Controllers;

use App\Services\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function __construct(protected ReportService $reportService) {}

    public function sales(Request $request): JsonResponse
    {
        $from = $request->get('from', today()->subDays(30)->format('Y-m-d'));
        $to = $request->get('to', today()->format('Y-m-d'));

        return response()->json($this->reportService->salesReport($from, $to));
    }

    public function topItems(Request $request): JsonResponse
    {
        $from = $request->get('from', today()->subDays(30)->format('Y-m-d'));
        $to = $request->get('to', today()->format('Y-m-d'));
        $limit = $request->get('limit', 10);

        return response()->json($this->reportService->topItems($from, $to, $limit));
    }

    public function categoryRevenue(Request $request): JsonResponse
    {
        $from = $request->get('from', today()->subDays(30)->format('Y-m-d'));
        $to = $request->get('to', today()->format('Y-m-d'));

        return response()->json($this->reportService->categoryRevenue($from, $to));
    }

    public function tableUsage(Request $request): JsonResponse
    {
        $from = $request->get('from', today()->subDays(30)->format('Y-m-d'));
        $to = $request->get('to', today()->format('Y-m-d'));

        return response()->json($this->reportService->tableUsage($from, $to));
    }

    public function dailySummary(): JsonResponse
    {
        return response()->json($this->reportService->dailySummary());
    }
}
