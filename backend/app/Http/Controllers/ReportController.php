<?php

namespace App\Http\Controllers;

use App\Services\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    protected ReportService $reportService;

    public function __construct(ReportService $reportService)
    {
        $this->reportService = $reportService;
    }

    public function dashboard(Request $request): JsonResponse
    {
        $branchId = $request->user()->branch_id ?? 1;
        $summary = $this->reportService->getDashboardSummary($branchId);

        return response()->json([
            'data' => $summary
        ]);
    }

    public function cashflow(Request $request): JsonResponse
    {
        $branchId = $request->user()->branch_id ?? 1;
        $report = $this->reportService->getCashflow(
            $branchId,
            $request->get('start_date'),
            $request->get('end_date')
        );

        return response()->json([
            'data' => $report
        ]);
    }

    public function demoQueries(Request $request): JsonResponse
    {
        $branchId = $request->user()->branch_id ?? 1;
        $queries = $this->reportService->getDemoQueries($branchId);

        return response()->json([
            'data' => $queries
        ]);
    }
}
