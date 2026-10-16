# Demo scenario PRD Bagian 4 + negative cases, executed against the live API.
$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:8000/api/v1'

function Post-JSON($uri, $body, $token, $headers) {
  $h = @{}
  if ($token) { $h['Authorization'] = "Bearer $token" }
  if ($headers) { $headers.GetEnumerator() | ForEach-Object { $h[$_.Key] = $_.Value } }
  Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $h -Body ($body | ConvertTo-Json -Depth 8)
}
function Patch-JSON($uri, $body, $token) {
  Invoke-RestMethod -Method Patch -Uri $uri -ContentType 'application/json' -Headers @{Authorization="Bearer $token"} -Body ($body | ConvertTo-Json -Depth 8)
}
function Get-API($uri, $token) {
  Invoke-RestMethod -Uri $uri -Headers @{Authorization="Bearer $token"}
}

# 1. Login pegawai
$staff = (Post-JSON "$base/auth/login" @{email='kasir1@laundryku.com'; password='password'} $null $null).data
$tok = $staff.token
Write-Host "1. Login pegawai OK (role=$($staff.user.role))"

# 2. Pick customer Budi
$customers = (Get-API "$base/customers" $tok).data
$budi = $customers | Where-Object { $_.name -like 'Budi*' } | Select-Object -First 1
Write-Host "2. Customer: $($budi.name)"

# 3. Services Kiloan Reguler + Sepatu
$services = (Get-API "$base/services" $tok).data
$kiloan = $services | Where-Object { $_.name -like 'Kiloan Reguler*' } | Select-Object -First 1
$sepatu = $services | Where-Object { $_.name -like 'Sepatu*' } | Select-Object -First 1
Write-Host "3. Services: $($kiloan.name) @$($kiloan.price), $($sepatu.name) @$($sepatu.price)"

# 4. Negative: diskon > 10% oleh pegawai -> harus gagal
$disc = [int]($kiloan.price * 3.2 * 0.5)
try {
  Post-JSON "$base/orders" @{customer_id=$budi.id; items=@(@{service_id=$kiloan.id; quantity=3.2}); discount_amount=$disc} $tok @{'Idempotency-Key'='neg-disc-1'} | Out-Null
  Write-Host "4. NEGATIVE DISCOUNT: UNEXPECTED SUCCESS"
} catch {
  Write-Host "4. Negative discount >10% ditolak OK ($($_.Exception.Response.StatusCode.value__))"
}

# 5. Buat order normal (Kiloan 3.2 kg + Sepatu 1)
$script:idem = "demo-$(Get-Random)"
$order = (Post-JSON "$base/orders" @{customer_id=$budi.id; items=@(
    @{service_id=$kiloan.id; quantity=3.2},
    @{service_id=$sepatu.id; quantity=1}
);} $tok @{'Idempotency-Key'=$script:idem}).data
Write-Host "5. Order $($order.order_no) total=$($order.total_amount) status=$($order.status) barcode=$($order.barcode)"

# 5b. Idempotency: repost key sama -> order yang sama, tidak dobel
$again = (Post-JSON "$base/orders" @{customer_id=$budi.id; items=@(@{service_id=$kiloan.id; quantity=1})} $tok @{'Idempotency-Key'=$script:idem}).data
if ($again.id -eq $order.id) { Write-Host "5b. Idempotency-Key OK (order sama, tidak duplikat)" } else { Write-Host "5b. IDEMPOTENCY FAIL" }

# 6. Negative: Diterima -> Siap langsung (422)
try {
  Patch-JSON "$base/orders/$($order.id)/status" @{status='Siap'} $tok | Out-Null
  Write-Host "6. INVALID TRANSITION: UNEXPECTED SUCCESS"
} catch {
  Write-Host "6. Negative Diterima->Siap ditolak OK ($($_.Exception.Response.StatusCode.value__))"
}

# 7. Negative: ke Ditimbang tanpa foto (422)
try {
  Patch-JSON "$base/orders/$($order.id)/status" @{status='Ditimbang'} $tok | Out-Null
  Write-Host "7. PHOTO GATE: UNEXPECTED SUCCESS"
} catch {
  Write-Host "7. Negative Ditimbang tanpa foto ditolak OK ($($_.Exception.Response.StatusCode.value__))"
}

# 8. Upload foto kondisi awal (1px png base64) lalu transisi berurutan
$png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
Post-JSON "$base/orders/$($order.id)/photos" @{photo=$png; photo_type='initial'} $tok $null | Out-Null
foreach ($s in @('Ditimbang','Dicuci','Disetrika','Siap')) {
  Patch-JSON "$base/orders/$($order.id)/status" @{status=$s} $tok | Out-Null
  Write-Host "8. Transisi -> $s OK"
}

# 9. Notifikasi selesai untuk pelanggan
$cust = (Post-JSON "$base/auth/login" @{email='budi@gmail.com'; password='password'} $null $null).data
$notifs = (Get-API "$base/notifications" $cust.token).data
$ready = $notifs | Where-Object { $_.type -eq 'ready' -and $_.message -like "*$($order.order_no)*" } | Select-Object -First 1
if ($ready) { Write-Host "9. Notifikasi 'ready' OK: $($ready.title)" } else { Write-Host "9. NOTIFIKASI READY MISSING"; $notifs | Select-Object -First 3 | Format-List }

# 10. Negatif: pelanggan akses dashboard -> 403
try {
  Get-API "$base/reports/dashboard" $cust.token | Out-Null
  Write-Host "10. RBAC: UNEXPECTED SUCCESS"
} catch {
  Write-Host "10. Pelanggan akses dashboard ditolak OK ($($_.Exception.Response.StatusCode.value__))"
}

# 11. Diambil -> pembayaran tunai lunas -> Lunas/Selesai + poin + kas
Patch-JSON "$base/orders/$($order.id)/status" @{status='Diambil'} $tok | Out-Null
$pointBefore = (Get-API "$base/customers/$($budi.id)/points" $tok).data.point_balance
Post-JSON "$base/orders/$($order.id)/payments" @{amount=$order.total_amount; payment_method='cash'} $tok @{'Idempotency-Key'="pay-$($order.id)"} | Out-Null
$final = (Get-API "$base/orders/$($order.id)" $tok).data
$pointAfter = (Get-API "$base/customers/$($budi.id)/points" $tok).data.point_balance
Write-Host "11. Status akhir=$($final.status), poin $pointBefore -> $pointAfter (harapan +$([Math]::Floor($order.total_amount/10000)))"

# 12. Dashboard pemilik
$owner = (Post-JSON "$base/auth/login" @{email='owner@laundryku.com'; password='password'} $null $null).data
$dash = (Get-API "$base/reports/dashboard" $owner.token).data
Write-Host "12. Dashboard: omzet hari ini=$($dash.today.omzet), order baru=$($dash.today.order_count), aktif=$($dash.active_orders_count), saldo kas=$($dash.current_balance)"

# 13. Cashflow: kas masuk bertambah dari pembayaran
$flow = (Get-API "$base/reports/cashflow" $owner.token).data
Write-Host "13. Cashflow 30 hari: masuk=$($flow.summary.total_in) keluar=$($flow.summary.total_out) net=$($flow.summary.net)"

Write-Host 'DEMO SCENARIO COMPLETE'
