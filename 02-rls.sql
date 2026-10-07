-- =====================================================================
-- 02-rls.sql  |  Aturan keamanan (Row Level Security)
--
-- Jalankan SETELAH 01-tabel.sql.
-- File ini aman dijalankan ulang: semua aturan lama di schema public
-- dihapus dulu, lalu dibuat ulang.
--
-- Ringkasan aturan:
--   * Pembeli    : hanya melihat pesanannya sendiri
--   * Penjual    : hanya melihat/mengubah kantin, menu, dan pesanan kantinnya sendiri
--   * Pengelola  : melihat semua profil, menyetujui penjual, mengelola pengumuman
--   * Membuat pesanan & mengubah status pesanan HANYA lewat fungsi di 03-fungsi.sql
-- =====================================================================


-- 0) Hapus semua policy lama di schema public (supaya file ini bisa diulang)
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname
           from pg_policies where schemaname = 'public'
  loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;


-- 1) FUNGSI BANTU
--    "security definer" = dijalankan dengan hak pemilik database, sehingga bisa
--    membaca tabel profiles tanpa membuat aturan saling memanggil (looping).
--    Semua fungsi ini hanya menjawab ya/tidak tentang pengguna yang sedang login.

create or replace function public.saya_pengelola()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and peran = 'pengelola' and status_akun = 'aktif'
  );
$$;

create or replace function public.saya_aktif()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and status_akun = 'aktif'
  );
$$;

create or replace function public.penjual_aktif(p_uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = p_uid and peran = 'penjual' and status_akun = 'aktif'
  );
$$;

-- Apakah kantin ini milik penjual yang sedang login (dan penjualnya sudah disetujui)?
create or replace function public.kantin_milik_saya(p_kantin_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.kantin k
    where k.id = p_kantin_id
      and k.pemilik_id = auth.uid()
      and public.penjual_aktif(k.pemilik_id)
  );
$$;

-- Apakah kantin ini boleh dilihat pembeli? (pemiliknya penjual yang aktif)
create or replace function public.kantin_terlihat(p_kantin_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.kantin k
    where k.id = p_kantin_id and public.penjual_aktif(k.pemilik_id)
  );
$$;


-- 2) PROFILES
--    Tidak ada policy "insert": profil dibuat otomatis oleh trigger saat daftar.
create policy "profil: lihat milik sendiri"
  on public.profiles for select to authenticated
  using (id = auth.uid());

create policy "profil: pengelola lihat semua"
  on public.profiles for select to authenticated
  using (public.saya_pengelola());

create policy "profil: ubah milik sendiri"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy "profil: pengelola ubah status akun"
  on public.profiles for update to authenticated
  using (public.saya_pengelola()) with check (public.saya_pengelola());
-- Kolom peran/status tetap dijaga oleh trigger di 03-fungsi.sql.


-- 3) KANTIN
--    Tidak ada policy "insert"/"delete": kantin dibuat otomatis saat penjual daftar.
create policy "kantin: lihat"
  on public.kantin for select to authenticated
  using (
    pemilik_id = auth.uid()
    or public.saya_pengelola()
    or (public.saya_aktif() and public.penjual_aktif(pemilik_id))
  );

create policy "kantin: penjual ubah miliknya"
  on public.kantin for update to authenticated
  using (pemilik_id = auth.uid() and public.penjual_aktif(auth.uid()))
  with check (pemilik_id = auth.uid());


-- 4) MENU
create policy "menu: lihat"
  on public.menu for select to authenticated
  using (
    public.kantin_milik_saya(kantin_id)
    or public.saya_pengelola()
    or (public.saya_aktif() and public.kantin_terlihat(kantin_id))
  );

create policy "menu: penjual tambah"
  on public.menu for insert to authenticated
  with check (public.kantin_milik_saya(kantin_id));

create policy "menu: penjual ubah"
  on public.menu for update to authenticated
  using (public.kantin_milik_saya(kantin_id))
  with check (public.kantin_milik_saya(kantin_id));

create policy "menu: penjual hapus"
  on public.menu for delete to authenticated
  using (public.kantin_milik_saya(kantin_id));


-- 5) PESANAN
--    Hanya boleh DILIHAT lewat tabel. Membuat dan mengubah pesanan lewat fungsi
--    (buat_pesanan, ubah_status_pesanan, batalkan_pesanan) agar harga, total,
--    stok, dan alur status tidak bisa dimanipulasi dari browser.
create policy "pesanan: pembeli lihat miliknya, penjual lihat kantinnya"
  on public.pesanan for select to authenticated
  using (pembeli_id = auth.uid() or public.kantin_milik_saya(kantin_id));


-- 6) ITEM_PESANAN: boleh dilihat kalau pesanan induknya boleh dilihat
--    (pengecekan di dalam "exists" ikut terkena aturan tabel pesanan)
create policy "item pesanan: ikut aturan pesanan"
  on public.item_pesanan for select to authenticated
  using (exists (select 1 from public.pesanan p where p.id = item_pesanan.pesanan_id));


-- 7) PENGUMUMAN
create policy "pengumuman: pengguna aktif lihat yang aktif"
  on public.pengumuman for select to authenticated
  using (aktif and public.saya_aktif());

create policy "pengumuman: pengelola kelola semua"
  on public.pengumuman for all to authenticated
  using (public.saya_pengelola()) with check (public.saya_pengelola());


-- 8) ANTREAN_HARIAN: sengaja TANPA policy = tidak bisa diakses dari browser.
--    Hanya fungsi buat_pesanan yang boleh mengubahnya.
