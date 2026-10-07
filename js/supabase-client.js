// supabase-client.js - menghubungkan website ke Supabase.
// Isi dua nilai di bawah dengan data proyekmu (Settings -> API Keys / Data API).
//
// AMAN ditaruh di sini : Project URL dan PUBLISHABLE key (sb_publishable_...)
// JANGAN PERNAH di sini: SECRET key (sb_secret_...) atau service_role.

const SUPABASE_URL = 'https://bkpiipyauksrtacibwss.supabase.co/rest/v1/';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_BYZjvHYNU8gWDYcd45A9Nw_7WNxh2KE';

// "db" dipakai semua halaman untuk bicara dengan Supabase.
// (Library-nya dimuat lebih dulu lewat tag <script> di tiap halaman.)
const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

function kunciSudahDiisi() {
  return !SUPABASE_URL.startsWith('GANTI') && !SUPABASE_PUBLISHABLE_KEY.startsWith('GANTI');
}
