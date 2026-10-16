<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Customer;
use App\Models\Order;
use App\Models\Service;
use App\Models\User;
use App\Services\JwtService;
use App\Services\OrderService;
use App\Services\PaymentService;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class LaundryTest extends TestCase
{
    use DatabaseTransactions;

    protected User $owner;
    protected User $staff;
    protected User $customerUser;
    protected Customer $customer;
    protected Service $kiloan;
    protected string $ownerToken;
    protected string $staffToken;
    protected string $customerToken;

    protected function setUp(): void
    {
        parent::setUp();

        $jwt = app(JwtService::class);

        $this->owner = User::where('email', 'owner@laundryku.com')->first();
        $this->staff = User::where('email', 'kasir1@laundryku.com')->first();
        $this->customerUser = User::where('email', 'budi@gmail.com')->first();
        $this->customer = Customer::where('user_id', $this->customerUser->id)->first();
        $this->kiloan = Service::where('name', 'Kiloan Reguler')->first();

        $this->ownerToken = $jwt->generateToken($this->owner);
        $this->staffToken = $jwt->generateToken($this->staff);
        $this->customerToken = $jwt->generateToken($this->customerUser);
    }

    public function test_login_returns_jwt_token(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'owner@laundryku.com',
            'password' => 'password',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'token',
                    'user' => ['id', 'name', 'email', 'role']
                ]
            ]);
    }

    public function test_rbac_owner_endpoint_forbidden_for_staff(): void
    {
        $response = $this->withHeader('Authorization', "Bearer {$this->staffToken}")
            ->getJson('/api/v1/reports/dashboard');

        $response->assertStatus(403);
    }

    public function test_rbac_owner_can_access_dashboard(): void
    {
        $response = $this->withHeader('Authorization', "Bearer {$this->ownerToken}")
            ->getJson('/api/v1/reports/dashboard');

        $response->assertStatus(200)
            ->assertJsonStructure(['data' => ['today', 'status_counts', 'current_balance']]);
    }

    public function test_create_order_snapshots_price_and_generates_order_no(): void
    {
        $response = $this->withHeader('Authorization', "Bearer {$this->staffToken}")
            ->postJson('/api/v1/orders', [
                'customer_id' => $this->customer->id,
                'items' => [
                    [
                        'service_id' => $this->kiloan->id,
                        'quantity' => 3.2,
                    ]
                ],
            ]);

        $response->assertStatus(201);
        $orderData = $response->json('data');

        $this->assertStringStartsWith('LDRY-', $orderData['order_no']);
        $this->assertEquals($orderData['order_no'], $orderData['barcode']);
        $this->assertEquals(OrderStatus::Diterima->value, $orderData['status']);

        // Check snapshot price
        $this->assertEquals($this->kiloan->price, $orderData['items'][0]['unit_price']);
    }

    public function test_discount_over_10_percent_rejected_for_staff(): void
    {
        $response = $this->withHeader('Authorization', "Bearer {$this->staffToken}")
            ->postJson('/api/v1/orders', [
                'customer_id' => $this->customer->id,
                'items' => [
                    [
                        'service_id' => $this->kiloan->id,
                        'quantity' => 5.0, // Subtotal 35.000
                    ]
                ],
                'discount_amount' => 10000, // > 10% (3.500)
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');
    }

    public function test_invalid_status_transition_rejected(): void
    {
        // Negative test: Diterima straight to Siap
        $order = Order::where('status', OrderStatus::Diterima->value)->first();

        $response = $this->withHeader('Authorization', "Bearer {$this->staffToken}")
            ->patchJson("/api/v1/orders/{$order->id}/status", [
                'status' => OrderStatus::Siap->value,
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_transition_to_ditimbang_requires_initial_photo(): void
    {
        // Create fresh order with no photo
        $orderService = app(OrderService::class);
        $order = $orderService->createOrder([
            'customer_id' => $this->customer->id,
            'items' => [['service_id' => $this->kiloan->id, 'quantity' => 2.0]],
        ], $this->staff);

        // Attempt transition without photo -> must fail with 422
        $response = $this->withHeader('Authorization', "Bearer {$this->staffToken}")
            ->patchJson("/api/v1/orders/{$order->id}/status", [
                'status' => OrderStatus::Ditimbang->value,
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_TRANSITION');

        // Now upload initial photo
        $this->withHeader('Authorization', "Bearer {$this->staffToken}")
            ->postJson("/api/v1/orders/{$order->id}/photos", [
                'photo' => 'https://example.com/photo.jpg',
                'photo_type' => 'initial',
            ])->assertStatus(201);

        // Retry transition -> now must succeed!
        $responseSuccess = $this->withHeader('Authorization', "Bearer {$this->staffToken}")
            ->patchJson("/api/v1/orders/{$order->id}/status", [
                'status' => OrderStatus::Ditimbang->value,
            ]);

        $responseSuccess->assertStatus(200)
            ->assertJsonPath('data.status', OrderStatus::Ditimbang->value);
    }

    public function test_payment_advances_order_and_adds_points(): void
    {
        $orderService = app(OrderService::class);
        $order = $orderService->createOrder([
            'customer_id' => $this->customer->id,
            'items' => [['service_id' => $this->kiloan->id, 'quantity' => 3.0]], // 21.000
        ], $this->staff);

        // Advance to Diambil (with photo)
        $order->photos()->create([
            'photo_path' => 'https://example.com/photo.jpg',
            'photo_type' => 'initial',
            'uploaded_by_user_id' => $this->staff->id,
        ]);
        $orderService->transition($order, OrderStatus::Ditimbang, $this->staff);
        $orderService->transition($order, OrderStatus::Dicuci, $this->staff);
        $orderService->transition($order, OrderStatus::Disetrika, $this->staff);
        $orderService->transition($order, OrderStatus::Siap, $this->staff);
        $orderService->transition($order, OrderStatus::Diambil, $this->staff);

        $initialPoints = $this->customer->fresh()->point_balance;

        // Process payment
        $response = $this->withHeader('Authorization', "Bearer {$this->staffToken}")
            ->postJson("/api/v1/orders/{$order->id}/payments", [
                'amount' => $order->total_amount,
                'payment_method' => 'cash',
            ]);

        $response->assertStatus(201);

        // Order must be Selesai
        $this->assertEquals(OrderStatus::Selesai->value, $order->fresh()->status);

        // Points should be increased by intdiv(21000, 10000) = 2
        $this->assertEquals($initialPoints + 2, $this->customer->fresh()->point_balance);
    }
}
