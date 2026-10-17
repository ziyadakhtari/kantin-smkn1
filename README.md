# Pelayanan Kantin SMK Negeri 1 Cimahi

Website pemesanan makanan kantin sekolah. Siswa, guru, dan pegawai memesan dari kelas,
lalu mengambil pesanan di kantin memakai nomor antrean. Pembayaran Cash atau QRIS dilakukan
langsung di kantin saat mengambil pesanan.

**Teknologi:** HTML, CSS, JavaScript biasa (tanpa framework). Database, login, penyimpanan
foto, dan status realtime memakai Supabase. Website dipublikasikan lewat GitHub Pages.

## Peran pengguna
| Peran | Cara mendapat akun | Bisa apa |
|---|---|---|
| Pengelola | Dibuat manual di dashboard Supabase (`sql/04-buat-pengelola.sql`) | Menyetujui penjual, menonaktifkan/mengaktifkan akun, melihat ringkasan kantin, membuat pengumuman |
| Penjual | Daftar sendiri, menunggu persetujuan pengelola | Kelola menu dan stok, profil kantin dan QRIS, buka/tutup kantin, proses pesanan, laporan |
| Pembeli | Daftar sendiri, langsung aktif | Lihat kantin dan menu, keranjang, pesan, pantau status, batalkan (saat Diterima), riwayat |

## Struktur folder
```
index.html, login.html, daftar-pembeli.html, daftar-penjual.html
pembeli/    kantin, menu, keranjang, checkout, pesanan, riwayat, profil
penjual/    dashboard, menu, profil-kantin, laporan
pengelola/  dashboard, persetujuan, akun, pengumuman
css/style.css            warna dan gaya (ubah di bagian :root)
js/                      supabase-client, ui, guard, auth, keranjang, unggah
sql/                     skrip database (urutan di bawah)
img/logo-smkn1.png       logo sekolah
```

## Menyiapkan dari nol
1. Buat proyek Supabase. Matikan "Confirm email" di Authentication > Sign In / Providers > Email.
2. Jalankan skrip di SQL Editor **berurutan**: `01-tabel`, `02-rls`, `03-fungsi`, `05-storage`, `06-laporan`, `07-pengelola`.
3. Isi `js/supabase-client.js` dengan Project URL dan **publishable key**.
4. Buat akun pengelola: Authentication > Users > Add user (centang Auto Confirm), lalu jalankan `sql/04-buat-pengelola.sql`.
5. Unggah ke GitHub, aktifkan GitHub Pages (Settings > Pages > branch main, folder root).
6. Jalankan `sql/08-uji-keamanan.sql`: semua baris hasil harus **LULUS**.

## Keamanan (penting)
- **Boleh** ada di kode: Project URL dan publishable key (`sb_publishable_...`).
- **Jangan pernah** ada di kode atau GitHub: secret key (`sb_secret_...`), `service_role`, password database.
- Keamanan data ada di aturan RLS database, bukan di tampilan website.
- Harga, total, stok, dan nomor antrean dihitung oleh database (fungsi `buat_pesanan`), bukan oleh browser.
- Aktifkan verifikasi dua langkah (2FA) di akun GitHub dan akun Supabase pemilik proyek.

## Perawatan
- Paket gratis Supabase menghentikan proyek yang tidak ada aktivitas selama 1 minggu. Waspadai libur sekolah.
  Lihat `.github/workflows/jaga-aktif.yml` (opsional) atau buka website secara berkala.
- Paket gratis tidak punya cadangan otomatis. Ekspor data penting secara berkala.
- Setelah mengubah aturan keamanan atau fungsi, jalankan ulang `sql/08-uji-keamanan.sql`.
