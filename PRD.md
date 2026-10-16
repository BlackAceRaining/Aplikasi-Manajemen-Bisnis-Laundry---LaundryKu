# PRD Prototipe LaundryKu

Versi 1.0 | 12 Oktober 2026 | Turunan dari PRD LaundryKu v1.0 (3 Oktober 2026)

Dokumen ini membatasi cakupan PRD utama menjadi satu alur inti yang dapat diselesaikan dan dipresentasikan dalam waktu satu minggu. Kode kebutuhan (FR, BR, M) merujuk pada PRD utama agar tetap dapat ditelusuri.

## 1. Tujuan Prototipe

1. Membuktikan bahwa rancangan basis data (18 tabel) berfungsi untuk satu siklus order penuh.
2. Mendemonstrasikan alur inti: order, nota barcode, status berurutan, notifikasi selesai, pembayaran, kas, poin, dan dashboard pemilik.
3. Menunjukkan penyelesaian masalah M1, M2 (sebagian), M3, M4 (sebagian), M5, M8, dan M9 (sebagian).

## 2. Cakupan

### 2.1 Termasuk (In Scope)

| Kode PRD utama | Kebutuhan | Catatan prototipe |
|---|---|---|
| FR-AUT-02, FR-AUT-03 | Login JWT dan RBAC | Peran: pemilik, pegawai, pelanggan. Satu cabang. |
| FR-LAY-01, 02, 03, 04 | Master layanan, hitung total, riwayat harga, estimasi durasi | Pemilik dapat mengubah harga, tercatat di riwayat dan audit. |
| FR-ORD-01, 02, 05 | Buat order, nomor unik, pencarian | Barcode berupa QR yang ditampilkan di layar. |
| FR-STA-01, 02, 03 | State machine, pindai barcode, log status | Inti demo. |
| FR-STA-04, 05, 06 | Notifikasi selesai, pengingat, Tidak Diambil | Notifikasi disimpan ke tabel `notifications` dan tampil di aplikasi. Pengingat dijalankan lewat perintah artisan. |
| FR-KLM-01 | Kondisi awal berfoto | Unggah foto saat tahap Ditimbang. |
| FR-KAS-01, 03, 04 | Pembayaran tunai, pengeluaran, cashflow | Hanya tunai dan transfer manual. |
| FR-PNT-01, 02 | Poin otomatis dan saldo poin | Penukaran poin cukup berupa pengurangan saldo. |
| FR-AUD-01, 02, 03, 05 | Audit log, otorisasi diskon, tanpa hapus, nomor nota berurutan | Diskon di atas 10 persen hanya dapat dibuat pemilik. |
| FR-LAP-01, 02 | Dashboard dan laporan omzet-laba | Versi sederhana per hari. |

### 2.2 Ditunda (Out of Scope Prototipe)

Kurir dan ongkir berbasis jarak, klaim dan komplain, deteksi anomali, mode offline, payment gateway dan webhook, printer thermal Bluetooth, FCM, peta, ekspor PDF dan CSV, harga per cabang, laporan pelanggan tidak aktif, registrasi OTP.

## 3. Pengguna dan Skenario

| Aktor | Skenario utama |
|---|---|
| Pegawai | Login, membuat order, memotret kondisi awal, memindai barcode untuk memajukan status, mencatat pembayaran. |
| Pemilik | Login, mengubah harga layanan, menyetujui diskon besar, melihat dashboard dan audit log. |
| Pelanggan | Login, melihat daftar order, linimasa status, notifikasi, dan saldo poin. |

## 4. Alur Demo (Acceptance Scenario)

1. Pegawai login, memilih pelanggan "Budi", menambah layanan Kiloan 3,2 kg dan Sepatu 1 pasang.
2. Sistem menghitung total otomatis dan membuat nomor order `LDRY-20261019-0001` beserta QR.
3. Pegawai mengunggah foto kondisi awal dan mengubah status Diterima menjadi Ditimbang.
4. Pegawai memindai QR dan memajukan status Dicuci, Disetrika, lalu Siap.
5. Sistem mencatat notifikasi "cucian selesai", mengisi `completed_at`, dan menghitung `due_at` (BR-06).
6. Pelanggan membuka aplikasi dan melihat linimasa serta notifikasi.
7. Pegawai memindai QR saat pengambilan (Diambil), mencatat pembayaran tunai, lalu status menjadi Lunas dan Selesai.
8. Sistem otomatis menulis kas masuk dan menambah poin (BR-08).
9. Pemilik membuka dashboard dan melihat omzet, jumlah order, serta order aktif bertambah sesuai transaksi.
10. Percobaan negatif: memajukan status dari Diterima langsung ke Siap ditolak dengan galat 422.

## 5. Kebutuhan Fungsional Prototipe

| ID | Kebutuhan | Kriteria penerimaan |
|---|---|---|
| P-01 | Login dengan JWT dan pembatasan peran | Endpoint pemilik ditolak (403) untuk pegawai dan pelanggan. |
| P-02 | CRUD layanan oleh pemilik | Setiap perubahan harga menambah baris di `service_price_histories` dan `audit_logs`. |
| P-03 | Pembuatan order | `unit_price` pada `order_items` sama dengan harga saat transaksi. Mengubah harga kemudian tidak mengubah order lama. |
| P-04 | Nomor order berurutan tanpa celah | Dibuat di dalam transaksi basis data dengan kunci baris. Tidak ada endpoint untuk mengubah `order_no`. |
| P-05 | State machine status | Hanya transisi pada Bagian 6 yang diterima. Transisi mundur hanya oleh pemilik dengan alasan. Setiap transisi menulis `order_status_logs`. |
| P-06 | Foto kondisi awal wajib sebelum Ditimbang | Transisi ke Ditimbang ditolak bila belum ada `order_photos` bertipe `initial`. |
| P-07 | Notifikasi selesai | Saat status Siap, satu baris `notifications` tipe `ready` dibuat untuk pelanggan. |
| P-08 | Pengingat batas pengambilan | Perintah `php artisan laundry:reminders` membuat notifikasi `reminder` dan menandai Tidak Diambil bila lewat `due_at`. |
| P-09 | Pembayaran | Satu transaksi basis data menulis `payments`, `cash_transactions`, dan bila lunas `loyalty_transactions` serta `customers.point_balance`. |
| P-10 | Diskon | Diskon lebih dari 10 persen subtotal ditolak kecuali dibuat oleh pemilik, dan dicatat di `audit_logs`. |
| P-11 | Cashflow dan pengeluaran | Pemilik dapat menambah pengeluaran. Laporan menampilkan kas masuk, kas keluar, dan saldo per hari. |
| P-12 | Dashboard pemilik | Menampilkan omzet hari ini, jumlah order, order aktif per status, dan order mendekati batas. |
| P-13 | Tanpa penghapusan transaksi | Tidak ada endpoint DELETE untuk order, pembayaran, atau kas. Pembatalan melalui status Dibatalkan dengan alasan. |

## 6. Siklus Status Order

Transisi yang diterima prototipe (mengacu Tabel 19 PRD utama):

| Dari | Ke | Aktor |
|---|---|---|
| (awal) | Diterima | Pegawai |
| Diterima | Ditimbang | Pegawai (syarat: foto kondisi awal) |
| Ditimbang | Dicuci | Pegawai |
| Dicuci | Disetrika | Pegawai |
| Disetrika | Siap | Pegawai (efek: notifikasi, `completed_at`, `due_at`) |
| Siap | Diambil | Pegawai |
| Diambil | Lunas | Pegawai dan sistem (efek: kas masuk, poin) |
| Lunas | Selesai | Sistem |
| Siap | Tidak Diambil | Sistem (cron) |
| Diterima, Ditimbang | Dibatalkan | Pegawai dengan persetujuan pemilik, alasan wajib |

Catatan keputusan: prototipe mengikuti Tabel 19 yang menempatkan Lunas sebagai status. Pemisahan status pembayaran dari status pengerjaan (bagian 3.3 PRD utama) dicatat sebagai penyempurnaan lanjutan.

## 7. Basis Data

Seluruh 18 tabel pada kamus data PRD utama (Tabel 20) dibuat sebagai migration, yaitu: `roles`, `branches`, `branch_settings`, `users`, `customers`, `services`, `service_price_histories`, `orders`, `order_items`, `order_status_logs`, `order_photos`, `payments`, `cash_transactions`, `deliveries`, `claims`, `notifications`, `loyalty_transactions`, `audit_logs`.

Ketentuan:

- MySQL atau MariaDB, InnoDB, utf8mb4, waktu disimpan dalam UTC.
- Nilai uang disimpan sebagai bilangan bulat rupiah (BIGINT), bukan float.
- Tabel `audit_logs`, `order_status_logs`, `cash_transactions`, dan `loyalty_transactions` bersifat append-only. Koreksi dilakukan dengan transaksi lawan.
- Indeks pada `orders(order_no)`, `orders(barcode)`, `orders(status)`, `orders(due_at)`, `orders(customer_id)`, `orders(created_at)`.
- Tabel `deliveries` dan `claims` dibuat skemanya tetapi tidak dipakai pada demo.

### Data seed

1 cabang, 1 pemilik, 2 pegawai, 3 pelanggan, 6 layanan (Kiloan Reguler, Kiloan Express, Satuan Kemeja, Sepatu, Karpet per m2, Bed Cover), 15 sampai 20 order dengan status beragam, beberapa pembayaran, dan 5 pengeluaran operasional.

### Kueri demo

1. Omzet harian dalam 7 hari terakhir.
2. Jumlah order per status saat ini.
3. Order berstatus Siap yang `due_at` kurang dari 2 hari.
4. Pelanggan tanpa order dalam 30 hari terakhir.
5. Pendapatan per jenis layanan.

## 8. Endpoint API Prototipe

Prefiks `/api/v1`, format JSON, seluruh galat berbentuk `{ "error": { "code", "message" } }`.

| Metode dan jalur | Fungsi | Peran |
|---|---|---|
| POST /auth/login | Login dan token | Publik |
| GET /services | Daftar layanan | Semua |
| POST /services, PATCH /services/{id} | Kelola layanan | Pemilik |
| POST /orders | Buat order (Idempotency-Key) | Pegawai |
| GET /orders, GET /orders/{id} | Daftar dan detail | Sesuai peran |
| GET /orders/{id}/timeline | Linimasa status | Semua |
| POST /orders/{id}/photos | Unggah foto kondisi awal | Pegawai |
| PATCH /orders/{id}/status | Ubah status dengan validasi | Pegawai, Pemilik |
| POST /orders/{id}/payments | Catat pembayaran | Pegawai |
| GET /customers/{id}/points | Saldo dan riwayat poin | Pelanggan, Pegawai |
| POST /cash-transactions | Catat pengeluaran | Pemilik |
| GET /reports/dashboard | Ringkasan dashboard | Pemilik |
| GET /reports/cashflow | Cashflow per periode | Pemilik |
| GET /notifications | Notifikasi pengguna | Pelanggan |
| GET /audit-logs | Jejak audit | Pemilik |

## 9. Layar Aplikasi Flutter

1. Login.
2. Daftar order (filter status, pencarian nomor order).
3. Buat order (pilih pelanggan, tambah layanan, total otomatis, diskon).
4. Detail order (linimasa status, foto kondisi awal, tombol pindai, tombol pembayaran).
5. Pemindai QR.
6. Dashboard pemilik.
7. Tampilan pelanggan: order saya, notifikasi, poin.

## 10. Aturan Bisnis yang Diterapkan

BR-01 (snapshot harga), BR-02 (total order), BR-03 (pembulatan kiloan 0,1 kg, minimum 1 kg), BR-05 (estimasi selesai), BR-06 (batas pengambilan N = 7 hari, pengingat M = 2 hari), BR-07 (Tidak Diambil), BR-08 (1 poin per Rp10.000, dibulatkan ke bawah), BR-11 (ambang diskon 10 persen), BR-13 (status hanya maju), BR-14 (waktu UTC), BR-15 (laba kotor dan laba bersih).

## 11. Risiko

| Risiko | Mitigasi |
|---|---|
| Waktu tidak cukup untuk seluruh layar Flutter | Prioritaskan layar 1 sampai 4, dashboard boleh berupa tampilan statis dari API. |
| Pemindai kamera bermasalah saat demo | Sediakan input manual nomor order sebagai cadangan. |
| Koneksi atau server gagal saat presentasi | Siapkan video rekaman demo dan jalankan server lokal. |
| Galat transaksi pada pembayaran | Bungkus dalam satu transaksi basis data dan uji kasus gagal. |

## 12. Indikator Keberhasilan Prototipe

- Skenario demo Bagian 4 berjalan lengkap tanpa intervensi manual pada basis data.
- Percobaan negatif (transisi tidak valid, diskon berlebih) ditolak dengan pesan galat yang jelas.
- Kelima kueri demo menghasilkan angka yang konsisten dengan data transaksi.
- ERD yang diekspor dari basis data nyata cocok dengan ERD pada PRD utama.