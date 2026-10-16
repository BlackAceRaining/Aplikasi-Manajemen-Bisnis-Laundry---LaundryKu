# GEMINI.md

Instruksi untuk coding agent yang mengerjakan prototipe **LaundryKu**. Baca file ini dan `docs/PRD_Prototipe_LaundryKu.md` sebelum menulis kode apa pun. PRD adalah sumber kebenaran untuk cakupan, dan file ini adalah sumber kebenaran untuk cara kerja.

## 1. Ringkasan Proyek

LaundryKu adalah aplikasi mobile manajemen bisnis laundry. Prototipe ini hanya mengerjakan satu alur inti: order, nota barcode, status berurutan, notifikasi selesai, pembayaran, kas, poin, dan dashboard pemilik. Batas waktu pengerjaan satu minggu, jadi **jangan menambah fitur di luar PRD prototipe**.

## 2. Teknologi

| Lapisan | Teknologi |
|---|---|
| Mobile | Flutter (Dart), Riverpod, dio, flutter_secure_storage, mobile_scanner, qr_flutter |
| Backend | PHP 8.x, Laravel, autentikasi JWT |
| Basis data | MySQL atau MariaDB (InnoDB, utf8mb4) |
| Dokumentasi API | OpenAPI atau koleksi Postman |
| Pengujian | Pest atau PHPUnit (backend), flutter_test (mobile) |

## 3. Struktur Repositori

```
laundryku/
  AGENTS.md
  docs/
    PRD_Prototipe_LaundryKu.md
    PRD_Aplikasi_Laundry_LaundryKu.docx   # PRD utama, rujukan
  backend/                                # proyek Laravel
    app/
      Http/Controllers/
      Http/Requests/                      # validasi input
      Models/
      Services/                           # logika bisnis (OrderService, PaymentService, dst.)
      Enums/OrderStatus.php
    database/migrations/
    database/seeders/
    routes/api.php
    tests/
  mobile/                                 # proyek Flutter
    lib/
      core/                               # dio client, router, tema, penyimpanan token
      features/
        auth/
        orders/
        scan/
        dashboard/
        customer/
```

Logika bisnis diletakkan di `Services`, bukan di controller. Controller hanya memvalidasi, memanggil service, dan mengembalikan respons.

## 4. Perintah Umum

Sesuaikan bila struktur proyek berbeda.

```bash
# backend
cd backend
composer install
cp .env.example .env && php artisan key:generate
php artisan migrate:fresh --seed
php artisan serve
php artisan laundry:reminders        # pengingat dan penandaan Tidak Diambil
php artisan test

# mobile
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Jalankan `php artisan migrate:fresh --seed` dan `php artisan test` sebelum menyatakan suatu tugas selesai.

## 5. Aturan Wajib (Invariant)

Aturan ini berasal dari PRD dan tidak boleh dilanggar, walaupun lebih cepat.

1. **Snapshot harga (BR-01).** `order_items.unit_price` disalin dari `services.price` saat order dibuat. Jangan pernah menghitung ulang total order lama dari harga master.
2. **State machine (FR-STA-01, BR-13).** Seluruh perubahan status melewati satu method, misalnya `OrderService::transition()`. Daftar transisi yang valid berada di `OrderStatus` enum. Transisi di luar daftar menghasilkan galat 422. Transisi mundur hanya oleh pemilik dengan alasan tertulis. Jangan mengubah kolom `orders.status` dari tempat lain.
3. **Setiap transisi menulis `order_status_logs`** dalam transaksi basis data yang sama dengan perubahan status.
4. **Append-only.** Tabel `audit_logs`, `order_status_logs`, `cash_transactions`, dan `loyalty_transactions` tidak pernah di-UPDATE atau DELETE. Koreksi dilakukan dengan baris lawan.
5. **Tanpa DELETE transaksi (FR-AUD-03).** Jangan membuat endpoint DELETE untuk order, pembayaran, atau kas. Pembatalan memakai status Dibatalkan dengan alasan.
6. **Pembayaran atomik (P-09).** `payments`, `cash_transactions`, dan (bila lunas) `loyalty_transactions` serta `customers.point_balance` ditulis dalam satu `DB::transaction`.
7. **Nomor order tanpa celah (FR-AUD-05).** Format `LDRY-YYYYMMDD-NNNN`, dibangkitkan di dalam transaksi dengan penguncian baris. Nilai barcode sama dengan `order_no`. Tidak ada endpoint yang mengubah `order_no`.
8. **Foto kondisi awal wajib** sebelum transisi Diterima ke Ditimbang (FR-KLM-01).
9. **Diskon (BR-11).** Diskon di atas 10 persen subtotal ditolak kecuali pengguna berperan pemilik. Catat di `audit_logs`.
10. **Perubahan harga layanan** menulis `service_price_histories` dan `audit_logs` dalam satu transaksi.
11. **RBAC.** Cek peran di middleware atau policy, bukan di UI saja. Pelanggan hanya boleh membaca order miliknya sendiri.
12. **Uang adalah bilangan bulat rupiah** (BIGINT di basis data, `int` di Dart dan PHP). Dilarang memakai float untuk uang.
13. **Waktu disimpan UTC (BR-14).** Konversi ke zona waktu cabang (WITA) hanya pada lapisan tampilan.
14. **Idempotency.** `POST /orders` dan `POST /orders/{id}/payments` menerima header `Idempotency-Key`. Permintaan ulang dengan kunci sama mengembalikan hasil yang sama, bukan data ganda.

## 6. Konvensi API

- Prefiks `/api/v1`, JSON, autentikasi `Authorization: Bearer <token>`.
- Respons sukses: `{ "data": ... }`.
- Respons galat: `{ "error": { "code": "INVALID_TRANSITION", "message": "..." } }`.
- Kode HTTP: 401 belum login, 403 peran tidak berhak, 404 tidak ditemukan, 409 konflik (idempotency atau duplikat), 422 validasi atau transisi tidak valid.
- Validasi input memakai Form Request. Jangan percaya data dari klien untuk harga, total, atau peran.
- Daftar endpoint resmi ada di Bagian 8 PRD prototipe. Tambahan endpoint harus dicatat di PRD terlebih dahulu.

## 7. Konvensi Basis Data

- Satu migration per tabel, nama tabel dan kolom mengikuti kamus data PRD utama (Tabel 20) persis.
- Semua FK memakai `constrained()` dan indeks pada kolom yang dipakai filter: `order_no`, `barcode`, `status`, `due_at`, `customer_id`, `created_at`.
- Seeder harus idempoten terhadap `migrate:fresh --seed` dan menghasilkan data demo sesuai Bagian 7 PRD prototipe.
- Tabel `deliveries` dan `claims` dibuat skemanya saja. Jangan membuat logika untuknya.

## 8. Konvensi Kode

**PHP/Laravel**
- PSR-12, tipe pada parameter dan return, enum untuk status dan peran.
- Hindari query di dalam loop. Gunakan eager loading.
- Setiap service punya pengujian untuk jalur sukses dan minimal satu jalur gagal.

**Flutter/Dart**
- Struktur per fitur (`features/<nama>`), state dengan Riverpod.
- Seluruh pemanggilan API melalui satu klien dio di `core/`. Token disimpan di `flutter_secure_storage`.
- Tampilkan keadaan loading, galat, dan kosong pada setiap layar yang memuat data.
- Jalankan `flutter analyze` tanpa peringatan sebelum selesai.

**Umum**
- Nama kode (kelas, variabel, tabel) dalam bahasa Inggris, teks yang tampil ke pengguna dalam bahasa Indonesia.
- Jangan menaruh rahasia (kunci JWT, kata sandi basis data) di repositori. Gunakan `.env`.
- Komentar menjelaskan alasan, bukan mengulang isi kode.

## 9. Urutan Pengerjaan

Kerjakan berurutan. Jangan melompat ke Flutter sebelum API tahap sebelumnya lulus uji.

1. Migration 18 tabel dan seeder.
2. Auth JWT, middleware peran.
3. Layanan dan riwayat harga.
4. `OrderService`: buat order, snapshot harga, nomor order, diskon.
5. State machine dan `order_status_logs`, unggah foto kondisi awal.
6. Pembayaran, kas, poin dalam satu transaksi.
7. Perintah `laundry:reminders` dan notifikasi.
8. Endpoint laporan dashboard dan cashflow.
9. Flutter: login, daftar order, buat order.
10. Flutter: detail order, linimasa, pemindai QR, pembayaran.
11. Flutter: dashboard pemilik dan tampilan pelanggan.

## 10. Definition of Done

Sebuah tugas dianggap selesai bila:

- Perilakunya sesuai kriteria penerimaan pada PRD prototipe (ID P-xx terkait).
- Pengujian baru ada dan seluruh pengujian lulus.
- `migrate:fresh --seed` berjalan tanpa galat.
- Tidak ada pelanggaran terhadap Bagian 5.
- Skenario demo (Bagian 4 PRD prototipe) tetap berjalan setelah perubahan.

## 11. Yang Tidak Boleh Dilakukan

- Menambah fitur di luar Bagian 2.1 PRD prototipe (kurir, klaim, offline, payment gateway, FCM, peta, ekspor, dan sebagainya).
- Mengubah skema tabel tanpa memperbarui kamus data dan PRD.
- Menghapus atau menonaktifkan pengujian agar build lulus.
- Menulis nilai sensitif atau data pelanggan asli ke dalam seeder, log, atau repositori.
- Menjalankan perintah destruktif pada basis data selain `migrate:fresh` di lingkungan pengembangan.

## 12. Bila Ragu

Bila kebutuhan ambigu atau bertentangan, ikuti urutan rujukan ini: (1) PRD prototipe, (2) PRD utama, (3) file ini. Bila masih ambigu, pilih solusi paling sederhana yang tidak melanggar Bagian 5 dan catat asumsinya di komentar PR atau pesan commit.