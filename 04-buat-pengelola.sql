-- =====================================================================
-- 04-buat-pengelola.sql  |  Membuat akun Pengelola Kantin
--
-- Akun pengelola TIDAK bisa dibuat dari website. Caranya:
--
-- 1) Supabase -> Authentication -> Users -> Add user -> Create new user
--    Isi email dan password pengelola (buat password yang kuat),
--    centang "Auto Confirm User", lalu Create user.
--    (Email dan password ini JANGAN ditulis di kode atau GitHub.)
--
-- 2) SQL Editor -> New query -> ganti emailnya di bawah -> Run
-- =====================================================================

update public.profiles
set peran = 'pengelola',
    status_akun = 'aktif',
    nama = 'Pengelola Kantin',
    jenis_pembeli = null,
    kelas_jurusan = null
where email = 'GANTI-DENGAN-EMAIL-PENGELOLA';

-- Cek hasilnya: harus muncul 1 baris dengan peran = pengelola
select nama, email, peran, status_akun from public.profiles where peran = 'pengelola';
