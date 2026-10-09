// auth.js - proses login dan pendaftaran. Butuh: supabase-client.js, ui.js, guard.js

const PESAN_STATUS = {
  menunggu: 'Akun penjual kamu masih menunggu persetujuan pengelola kantin.',
  ditolak: 'Pendaftaran penjual kamu ditolak. Silakan hubungi pengelola kantin.',
  nonaktif: 'Akun kamu dinonaktifkan. Silakan hubungi pengelola kantin.'
};

function pesanError(error) {
  const m = (error.message || '').toLowerCase();
  if (m.includes('already registered')) return 'Email ini sudah terdaftar. Silakan masuk.';
  if (m.includes('invalid login')) return 'Email atau password salah.';
  if (m.includes('password should be')) return 'Password terlalu pendek.';
  if (m.includes('valid email') || m.includes('invalid format')) return 'Format email tidak valid.';
  if (m.includes('rate limit')) return 'Terlalu sering mencoba. Tunggu beberapa menit lalu coba lagi.';
  return 'Terjadi kesalahan: ' + error.message;
}

function tampilPesan(el, teks, jenis = '') {
  el.hidden = false;
  el.className = 'status-kotak ' + jenis;
  el.textContent = teks;
  el.style.marginBottom = '14px';
}

// ---------- LOGIN ----------
async function prosesLogin(e) {
  e.preventDefault();
  const f = e.target.elements;
  const tombol = e.target.querySelector('button[type=submit]');
  const pesan = document.getElementById('pesan');
  pesan.hidden = true;
  tombolSibuk(tombol, true, 'Memeriksa...');

  const { error } = await db.auth.signInWithPassword({
    email: f.email.value.trim(),
    password: f.password.value
  });
  if (error) {
    tampilPesan(pesan, pesanError(error), 'gagal');
    return tombolSibuk(tombol, false);
  }

  const profil = await ambilProfil();
  if (!profil) {
    await db.auth.signOut();
    tampilPesan(pesan, 'Data akun tidak ditemukan. Hubungi pengelola kantin.', 'gagal');
    return tombolSibuk(tombol, false);
  }
  if (profil.status_akun !== 'aktif') {
    await db.auth.signOut();
    tampilPesan(pesan, PESAN_STATUS[profil.status_akun] || 'Akun ini tidak aktif.', 'gagal');
    return tombolSibuk(tombol, false);
  }
  location.replace(AKAR + HALAMAN_PERAN[profil.peran]);
}

// ---------- DAFTAR ----------
function passwordCocok(f, pesan) {
  if (f.password.value !== f.password2.value) {
    tampilPesan(pesan, 'Password dan ulangi password tidak sama.', 'gagal');
    return false;
  }
  return true;
}

async function prosesDaftarPembeli(e) {
  e.preventDefault();
  const f = e.target.elements;
  const tombol = e.target.querySelector('button[type=submit]');
  const pesan = document.getElementById('pesan');
  pesan.hidden = true;
  if (!passwordCocok(f, pesan)) return;
  tombolSibuk(tombol, true, 'Mendaftarkan...');

  const jenis = f.jenis.value;
  const { data, error } = await db.auth.signUp({
    email: f.email.value.trim(),
    password: f.password.value,
    options: { data: {
      peran: 'pembeli',
      nama: f.nama.value.trim(),
      jenis_pembeli: jenis,
      kelas_jurusan: jenis === 'siswa' ? f.kelas.value.trim() : ''
    } }
  });
  if (error) {
    tampilPesan(pesan, pesanError(error), 'gagal');
    return tombolSibuk(tombol, false);
  }
  if (!data.session) { // terjadi bila konfirmasi email masih menyala di Supabase
    tampilPesan(pesan, 'Pendaftaran berhasil. Cek email kamu untuk konfirmasi, lalu masuk.', 'ok');
    return tombolSibuk(tombol, false);
  }
  location.replace(AKAR + HALAMAN_PERAN.pembeli);
}

async function prosesDaftarPenjual(e) {
  e.preventDefault();
  const f = e.target.elements;
  const tombol = e.target.querySelector('button[type=submit]');
  const pesan = document.getElementById('pesan');
  pesan.hidden = true;
  if (!passwordCocok(f, pesan)) return;
  tombolSibuk(tombol, true, 'Mendaftarkan...');

  const { error } = await db.auth.signUp({
    email: f.email.value.trim(),
    password: f.password.value,
    options: { data: {
      peran: 'penjual',
      nama: f.nama.value.trim(),
      nama_kantin: f.nama_kantin.value.trim(),
      no_hp: f.no_hp.value.trim()
    } }
  });
  if (error) {
    tampilPesan(pesan, pesanError(error), 'gagal');
    return tombolSibuk(tombol, false);
  }
  await db.auth.signOut(); // penjual baru belum boleh masuk sebelum disetujui
  e.target.hidden = true;
  tampilPesan(pesan, 'Pendaftaran berhasil. Akunmu menunggu persetujuan pengelola kantin. Setelah disetujui, kamu bisa masuk dan mulai berjualan.', 'ok');
}
