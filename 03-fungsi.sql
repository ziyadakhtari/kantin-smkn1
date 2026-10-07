-- =====================================================================
-- 03-fungsi.sql  |  Trigger dan fungsi database
--
-- Jalankan SETELAH 01-tabel.sql dan 02-rls.sql.
-- Aman dijalankan ulang (memakai "create or replace" / "drop trigger if exists").
--
-- Isi:
--   A. Profil otomatis dibuat saat orang mendaftar
--   B. Penjaga kolom profil (peran & status tidak bisa diubah sendiri)
--   C. Menu otomatis "habis" saat stok 0
--   D. buat_pesanan        -> harga & total dihitung di database, nomor antrean otomatis
--   E. ubah_status_pesanan -> dipakai penjual
--   F. batalkan_pesanan    -> dipakai pembeli (hanya saat status "diterima")
--   G. Realtime untuk tabel pesanan
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Profil otomatis saat daftar
--    Halaman daftar mengirim data tambahan (nama, no_hp, dst.) lewat
--    "user metadata". Peran hanya boleh 'pembeli' atau 'penjual'.
--    Peran 'pengelola' TIDAK PERNAH bisa didapat lewat pendaftaran.
-- ---------------------------------------------------------------------
create or replace function public.buat_profil_baru()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_meta   jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_peran  text  := coalesce(v_meta->>'peran', 'pembeli');
  v_nama   text  := nullif(trim(coalesce(v_meta->>'nama', '')), '');
  v_jenis  text  := v_meta->>'jenis_pembeli';
begin
  if v_peran not in ('pembeli', 'penjual') then
    v_peran := 'pembeli';
  end if;
  v_nama := coalesce(v_nama, split_part(new.email, '@', 1));

  if v_peran <> 'pembeli' or v_jenis not in ('siswa', 'guru', 'pegawai') then
    v_jenis := null;
  end if;

  insert into public.profiles
    (id, nama, email, no_hp, peran, jenis_pembeli, kelas_jurusan, status_akun)
  values (
    new.id,
    v_nama,
    new.email,
    nullif(trim(coalesce(v_meta->>'no_hp', '')), ''),
    v_peran,
    v_jenis,
    case when v_jenis = 'siswa' then nullif(trim(coalesce(v_meta->>'kelas_jurusan', '')), '') end,
    case when v_peran = 'penjual' then 'menunggu' else 'aktif' end
  );

  if v_peran = 'penjual' then
    insert into public.kantin (pemilik_id, nama_kantin)
    values (
      new.id,
      coalesce(nullif(trim(coalesce(v_meta->>'nama_kantin', '')), ''), 'Kantin ' || v_nama)
    );
  end if;

  return new;
end $$;

drop trigger if exists saat_pengguna_dibuat on auth.users;
create trigger saat_pengguna_dibuat
  after insert on auth.users
  for each row execute function public.buat_profil_baru();


-- ---------------------------------------------------------------------
-- B. Penjaga kolom profil
--    auth.uid() kosong = perintah datang dari SQL Editor / server rahasia,
--    jadi dibolehkan (di sinilah akun pengelola dibuat).
-- ---------------------------------------------------------------------
create or replace function public.jaga_kolom_profil()
returns trigger language plpgsql as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if new.id is distinct from old.id
     or new.peran is distinct from old.peran
     or new.email is distinct from old.email then
    raise exception 'Peran, email, dan id tidak boleh diubah.';
  end if;

  if new.status_akun is distinct from old.status_akun then
    if not public.saya_pengelola() then
      raise exception 'Hanya pengelola yang bisa mengubah status akun.';
    end if;
    if old.id = auth.uid() or old.peran = 'pengelola' then
      raise exception 'Status akun pengelola tidak bisa diubah dari aplikasi.';
    end if;
  end if;

  -- Pengelola yang mengubah akun orang lain hanya boleh mengubah status akun
  if old.id <> auth.uid()
     and (new.nama, new.no_hp, new.jenis_pembeli, new.kelas_jurusan)
         is distinct from (old.nama, old.no_hp, old.jenis_pembeli, old.kelas_jurusan) then
    raise exception 'Pengelola hanya boleh mengubah status akun.';
  end if;

  return new;
end $$;

drop trigger if exists jaga_kolom_profil on public.profiles;
create trigger jaga_kolom_profil
  before update on public.profiles
  for each row execute function public.jaga_kolom_profil();


-- ---------------------------------------------------------------------
-- C. Menu otomatis "habis" saat stok mencapai 0
-- ---------------------------------------------------------------------
create or replace function public.atur_status_habis()
returns trigger language plpgsql as $$
begin
  if new.stok is not null and new.stok <= 0 then
    new.habis := true;
  end if;
  return new;
end $$;

drop trigger if exists menu_atur_habis on public.menu;
create trigger menu_atur_habis
  before insert or update on public.menu
  for each row execute function public.atur_status_habis();


-- ---------------------------------------------------------------------
-- Fungsi internal: kembalikan stok saat pesanan dibatalkan
-- (hanya dipanggil oleh fungsi lain, tidak bisa dipanggil dari browser)
-- ---------------------------------------------------------------------
create or replace function public._kembalikan_stok(p_pesanan_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.menu m
  set stok  = m.stok + i.jumlah,
      habis = case when m.stok = 0 then false else m.habis end
  from public.item_pesanan i
  where i.pesanan_id = p_pesanan_id
    and i.menu_id = m.id
    and m.stok is not null;
end $$;

revoke all on function public._kembalikan_stok(uuid) from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- D. buat_pesanan
--    Dipanggil dari browser dengan:
--      supabase.rpc('buat_pesanan', {
--        p_kantin_id: '...', p_metode_bayar: 'cash' | 'qris',
--        p_catatan: 'tidak pedas',
--        p_item: [ { menu_id: '...', jumlah: 2 }, ... ]
--      })
--    Hasil: { pesanan_id, nomor_antrean, total }
--    Browser TIDAK mengirim harga. Harga diambil dari tabel menu.
-- ---------------------------------------------------------------------
create or replace function public.buat_pesanan(
  p_kantin_id     uuid,
  p_metode_bayar  text,
  p_catatan       text,
  p_item          jsonb
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid         uuid := auth.uid();
  v_profil      public.profiles%rowtype;
  v_kantin      public.kantin%rowtype;
  v_menu        public.menu%rowtype;
  v_tanggal     date := (now() at time zone 'Asia/Jakarta')::date;
  v_nomor       integer;
  v_total       integer := 0;
  v_pesanan_id  uuid;
  r             record;
begin
  if v_uid is null then
    raise exception 'Silakan masuk (login) dulu.';
  end if;

  select * into v_profil from public.profiles where id = v_uid;
  if not found or v_profil.peran <> 'pembeli' or v_profil.status_akun <> 'aktif' then
    raise exception 'Akun ini tidak bisa membuat pesanan.';
  end if;

  if p_metode_bayar not in ('cash', 'qris') then
    raise exception 'Metode bayar tidak valid.';
  end if;

  if p_item is null or jsonb_typeof(p_item) <> 'array'
     or jsonb_array_length(p_item) = 0 or jsonb_array_length(p_item) > 50 then
    raise exception 'Keranjang kosong atau tidak valid.';
  end if;

  select * into v_kantin from public.kantin where id = p_kantin_id;
  if not found or not public.penjual_aktif(v_kantin.pemilik_id) then
    raise exception 'Kantin tidak ditemukan.';
  end if;
  if not v_kantin.sedang_buka then
    raise exception 'Kantin sedang tutup.';
  end if;
  if p_metode_bayar = 'qris' and v_kantin.qris_url is null then
    raise exception 'Kantin ini belum menyediakan QRIS.';
  end if;

  -- Nomor antrean: urut per kantin, mulai dari 1 setiap hari (waktu WIB)
  insert into public.antrean_harian (kantin_id, tanggal, nomor_terakhir)
  values (p_kantin_id, v_tanggal, 1)
  on conflict (kantin_id, tanggal)
  do update set nomor_terakhir = public.antrean_harian.nomor_terakhir + 1
  returning nomor_terakhir into v_nomor;

  insert into public.pesanan
    (pembeli_id, kantin_id, nama_pembeli, jenis_pembeli,
     nomor_antrean, tanggal_antrean, metode_bayar, catatan)
  values
    (v_uid, p_kantin_id, v_profil.nama, v_profil.jenis_pembeli,
     v_nomor, v_tanggal, p_metode_bayar,
     nullif(left(trim(coalesce(p_catatan, '')), 200), ''))
  returning id into v_pesanan_id;

  -- Gabungkan menu yang sama, lalu proses satu per satu
  -- (urut berdasarkan menu_id supaya tidak saling mengunci)
  for r in
    select (e->>'menu_id')::uuid as menu_id,
           sum((e->>'jumlah')::integer)::integer as jumlah
    from jsonb_array_elements(p_item) as e
    group by 1
    order by 1
  loop
    if r.jumlah < 1 or r.jumlah > 50 then
      raise exception 'Jumlah tiap menu harus antara 1 sampai 50.';
    end if;

    select * into v_menu
    from public.menu
    where id = r.menu_id and kantin_id = p_kantin_id
    for update;

    if not found then
      raise exception 'Ada menu yang tidak ditemukan di kantin ini.';
    end if;
    if v_menu.habis or (v_menu.stok is not null and v_menu.stok < r.jumlah) then
      raise exception 'Menu "%" habis atau stoknya tidak cukup.', v_menu.nama;
    end if;

    insert into public.item_pesanan (pesanan_id, menu_id, nama_menu, jumlah, harga_satuan)
    values (v_pesanan_id, v_menu.id, v_menu.nama, r.jumlah, v_menu.harga);

    v_total := v_total + v_menu.harga * r.jumlah;

    if v_menu.stok is not null then
      update public.menu set stok = stok - r.jumlah where id = v_menu.id;
    end if;
  end loop;

  update public.pesanan set total = v_total where id = v_pesanan_id;

  return jsonb_build_object(
    'pesanan_id',    v_pesanan_id,
    'nomor_antrean', v_nomor,
    'total',         v_total
  );
end $$;


-- ---------------------------------------------------------------------
-- E. ubah_status_pesanan  (untuk PENJUAL)
--    Alur: diterima -> diproses -> siap_diambil -> selesai
--    Penjual juga boleh membatalkan selama pesanan belum selesai.
-- ---------------------------------------------------------------------
create or replace function public.ubah_status_pesanan(p_pesanan_id uuid, p_status_baru text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_pesanan public.pesanan%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Silakan masuk (login) dulu.';
  end if;

  select * into v_pesanan from public.pesanan where id = p_pesanan_id for update;
  if not found then
    raise exception 'Pesanan tidak ditemukan.';
  end if;

  if not public.kantin_milik_saya(v_pesanan.kantin_id) then
    raise exception 'Kamu tidak berhak mengubah pesanan ini.';
  end if;

  if not (
       (v_pesanan.status = 'diterima'     and p_status_baru in ('diproses', 'dibatalkan'))
    or (v_pesanan.status = 'diproses'     and p_status_baru in ('siap_diambil', 'dibatalkan'))
    or (v_pesanan.status = 'siap_diambil' and p_status_baru in ('selesai', 'dibatalkan'))
  ) then
    raise exception 'Status tidak bisa diubah dari "%" ke "%".', v_pesanan.status, p_status_baru;
  end if;

  update public.pesanan
  set status = p_status_baru, diperbarui_pada = now()
  where id = p_pesanan_id;

  if p_status_baru = 'dibatalkan' then
    perform public._kembalikan_stok(p_pesanan_id);
  end if;
end $$;


-- ---------------------------------------------------------------------
-- F. batalkan_pesanan  (untuk PEMBELI, hanya saat status masih "diterima")
-- ---------------------------------------------------------------------
create or replace function public.batalkan_pesanan(p_pesanan_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_pesanan public.pesanan%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Silakan masuk (login) dulu.';
  end if;

  select * into v_pesanan
  from public.pesanan
  where id = p_pesanan_id and pembeli_id = auth.uid()
  for update;

  if not found then
    raise exception 'Pesanan tidak ditemukan.';
  end if;
  if v_pesanan.status <> 'diterima' then
    raise exception 'Pesanan sudah diproses, jadi tidak bisa dibatalkan.';
  end if;

  update public.pesanan
  set status = 'dibatalkan', diperbarui_pada = now()
  where id = p_pesanan_id;

  perform public._kembalikan_stok(p_pesanan_id);
end $$;


-- ---------------------------------------------------------------------
-- Izin menjalankan fungsi: hanya pengguna yang sudah login
-- ---------------------------------------------------------------------
revoke all on function public.buat_pesanan(uuid, text, text, jsonb) from public, anon;
revoke all on function public.ubah_status_pesanan(uuid, text)       from public, anon;
revoke all on function public.batalkan_pesanan(uuid)                from public, anon;

grant execute on function public.buat_pesanan(uuid, text, text, jsonb) to authenticated;
grant execute on function public.ubah_status_pesanan(uuid, text)       to authenticated;
grant execute on function public.batalkan_pesanan(uuid)                to authenticated;


-- ---------------------------------------------------------------------
-- G. Realtime: perubahan tabel pesanan dikirim langsung ke browser
--    (tetap mengikuti aturan RLS: pembeli hanya menerima pesanannya sendiri,
--     penjual hanya pesanan kantinnya)
-- ---------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.pesanan;
exception
  when duplicate_object then null;   -- sudah terdaftar, abaikan
end $$;
