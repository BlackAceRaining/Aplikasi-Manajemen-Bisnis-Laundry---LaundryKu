<?php

namespace App\Http\Controllers;

use App\Models\Service;
use App\Models\ServicePriceHistory;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ServiceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $services = Service::where('is_active', true)
            ->orderBy('id', 'asc')
            ->get();

        return response()->json([
            'data' => $services
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|max:100',
            'unit' => 'required|string|in:kg,pcs,pasang,m2',
            'price' => 'required|integer|min:1',
            'estimate_duration_hours' => 'required|integer|min:1',
            'min_order' => 'nullable|numeric|min:0.1',
        ]);

        $user = $request->user();
        $branchId = $user->branch_id ?? 1;

        $service = Service::create([
            'branch_id' => $branchId,
            'name' => $request->name,
            'unit' => $request->unit,
            'price' => (int) $request->price,
            'estimate_duration_hours' => (int) $request->estimate_duration_hours,
            'min_order' => (float) ($request->min_order ?? 1.0),
            'is_active' => true,
        ]);

        AuditService::log(
            action: 'create_service',
            entityType: 'Service',
            entityId: (string) $service->id,
            oldValues: null,
            newValues: $service->toArray(),
            userId: $user->id
        );

        return response()->json([
            'data' => $service
        ], 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $service = Service::findOrFail($id);
        $user = $request->user();

        $request->validate([
            'name' => 'sometimes|string|max:100',
            'unit' => 'sometimes|string|in:kg,pcs,pasang,m2',
            'price' => 'sometimes|integer|min:1',
            'estimate_duration_hours' => 'sometimes|integer|min:1',
            'min_order' => 'sometimes|numeric|min:0.1',
            'reason' => 'nullable|string',
        ]);

        $oldPrice = (int) $service->price;
        $newPrice = $request->has('price') ? (int) $request->price : $oldPrice;
        $priceChanged = ($newPrice !== $oldPrice);

        DB::transaction(function () use ($service, $request, $user, $oldPrice, $newPrice, $priceChanged) {
            $oldValues = $service->toArray();

            $service->fill($request->only([
                'name', 'unit', 'price', 'estimate_duration_hours', 'min_order'
            ]));
            $service->save();

            // BR-10: Perubahan harga layanan menulis service_price_histories dan audit_logs dalam satu transaksi
            if ($priceChanged) {
                ServicePriceHistory::create([
                    'service_id' => $service->id,
                    'old_price' => $oldPrice,
                    'new_price' => $newPrice,
                    'changed_by_user_id' => $user->id,
                    'reason' => $request->reason ?? 'Penyesuaian tarif oleh pemilik',
                ]);

                AuditService::log(
                    action: 'update_service_price',
                    entityType: 'Service',
                    entityId: (string) $service->id,
                    oldValues: ['price' => $oldPrice],
                    newValues: ['price' => $newPrice, 'reason' => $request->reason],
                    userId: $user->id
                );
            } else {
                AuditService::log(
                    action: 'update_service',
                    entityType: 'Service',
                    entityId: (string) $service->id,
                    oldValues: $oldValues,
                    newValues: $service->toArray(),
                    userId: $user->id
                );
            }
        });

        return response()->json([
            'data' => $service->fresh()
        ]);
    }
}
