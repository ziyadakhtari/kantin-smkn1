-- =====================================================================
-- 01-tabel.sql  |  Membuat semua tabel Pelayanan Kantin SMKN 1 Cimahi
--
-- Cara pakai: Supabase -> SQL Editor -> New query -> tempel isi file ini -> Run
-- Urutan wajib: 01 -> 02 -> 03
-- File ini aman dijalankan ulang (memakai "if not exists").
-- =====================================================================


-- 1) PROFILES: data tambahan tiap pengguna (login-nya sendiri ada di Supabase Auth)
create table if not exists public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  nama           text not null,
  email          text,
  no_hp          text,
  peran          text not null default 'pembeli'
                   check (peran in ('pengelola', 'penjual', 'pembeli')),
  jenis_pembeli  text check (jenis_pembeli in ('siswa', 'guru', 'pegawai')),
  kelas_jurusan  text,                      -- hanya diisi untuk siswa
  status_akun    text not null default 'aktif'
                   check (status_akun in ('aktif', 'menunggu', 'ditolak', 'nonaktif')),
  dibuat_pada    timestamptz not null default now()
);


-- 2) KANTIN: satu penjual punya satu kantin/lapak
create table if not exists public.kantin (
  id           uuid primary key default gen_random_uuid(),
  pemilik_id   uuid not null unique references public.profiles(id) on delete cascade,
  nama_kantin  text not null,
  deskripsi    text,
  sedang_buka  boolean not null default false,
  qris_url     text,                        -- alamat gambar QRIS (diunggah penjual)
  dibuat_pada  timestamptz not null default now()
);


-- 3) MENU
create table if not exists public.menu (
  id           uuid primary key default gen_random_uuid(),
  kantin_id    uuid not null references public.kantin(id) on delete cascade,
  nama         text not null check (char_length(nama) <= 100),
  deskripsi    text,
  harga        integer not null check (harga >= 0 and harga <= 1000000),
  stok         integer check (stok >= 0),   -- NULL = stok tidak dibatasi
  kategori     text not null check (kategori in ('makanan berat', 'jajanan', 'minuman')),
  foto_url     text,
  habis        boolean not null default false,
  dibuat_pada  timestamptz not null default now()
);
create index if not exists idx_menu_kantin on public.menu (kantin_id);


-- 4) ANTREAN_HARIAN: tabel bantu agar nomor antrean urut dan reset tiap hari
create table if not exists public.antrean_harian (
  kantin_id       uuid not null references public.kantin(id) on delete cascade,
  tanggal         date not null,
  nomor_terakhir  integer not null default 0,
  primary key (kantin_id, tanggal)
);


-- 5) PESANAN
--    nama_pembeli & jenis_pembeli disalin saat pesan, supaya penjual cukup melihat
--    pesanan tanpa perlu membuka data profil pembeli (email/no HP tetap privat).
create table if not exists public.pesanan (
  id               uuid primary key default gen_random_uuid(),
  pembeli_id       uuid not null references public.profiles(id),
  kantin_id        uuid not null references public.kantin(id),
  nama_pembeli     text not null,
  jenis_pembeli    text,
  nomor_antrean    integer not null,
  tanggal_antrean  date not null,
  status           text not null default 'diterima'
                     check (status in ('diterima', 'diproses', 'siap_diambil', 'selesai', 'dibatalkan')),
  metode_bayar     text not null check (metode_bayar in ('cash', 'qris')),
  catatan          text check (char_length(catatan) <= 200),
  total            integer not null default 0 check (total >= 0),
  dibuat_pada      timestamptz not null default now(),
  diperbarui_pada  timestamptz not null default now(),
  unique (kantin_id, tanggal_antrean, nomor_antrean)
);
create index if not exists idx_pesanan_kantin  on public.pesanan (kantin_id, tanggal_antrean, status);
create index if not exists idx_pesanan_pembeli on public.pesanan (pembeli_id, dibuat_pada desc);


-- 6) ITEM_PESANAN: isi tiap pesanan (harga & nama disimpan saat dipesan)
create table if not exists public.item_pesanan (
  id            uuid primary key default gen_random_uuid(),
  pesanan_id    uuid not null references public.pesanan(id) on delete cascade,
  menu_id       uuid references public.menu(id) on delete set null,
  nama_menu     text not null,
  jumlah        integer not null check (jumlah > 0),
  harga_satuan  integer not null check (harga_satuan >= 0)
);
create index if not exists idx_item_pesanan on public.item_pesanan (pesanan_id);


-- 7) PENGUMUMAN dari pengelola
create table if not exists public.pengumuman (
  id           uuid primary key default gen_random_uuid(),
  judul        text not null,
  isi          text not null,
  aktif        boolean not null default true,
  dibuat_oleh  uuid references public.profiles(id) on delete set null,
  dibuat_pada  timestamptz not null default now()
);


-- 8) AKTIFKAN ROW LEVEL SECURITY di semua tabel.
--    Begitu RLS aktif, SEMUA akses ditolak sampai ada aturan (policy) yang
--    mengizinkan. Aturannya dibuat di 02-rls.sql.
alter table public.profiles       enable row level security;
alter table public.kantin         enable row level security;
alter table public.menu           enable row level security;
alter table public.antrean_harian enable row level security;
alter table public.pesanan        enable row level security;
alter table public.item_pesanan   enable row level security;
alter table public.pengumuman     enable row level security;
