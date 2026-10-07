// guard.js - penjaga halaman: cek login, cek peran, dan header bersama.
// CATATAN: penjaga ini hanya mengatur TAMPILAN. Keamanan data yang sebenarnya
// ada di aturan RLS di database, jadi menembus penjaga ini tidak membuka data orang lain.

// Alamat folder utama website (dihitung dari lokasi file ini), supaya link
// tetap benar di halaman mana pun dan di GitHub Pages.
const AKAR = new URL('../', document.currentScript.src).href;

const HALAMAN_PERAN = {
  pembeli: 'pembeli/kantin.html',
  penjual: 'penjual/dashboard.html',
  pengelola: 'pengelola/dashboard.html'
};

// Mengambil profil pengguna yang sedang login (atau null kalau belum login)
async function ambilProfil() {
  const { data: { session } } = await db.auth.getSession();
  if (!session) return null;
  const { data, error } = await db
    .from('profiles')
    .select('nama, peran, status_akun, jenis_pembeli')
    .eq('id', session.user.id)
    .single();
  return error ? null : data;
}

// Dipanggil di halaman yang dilindungi, contoh: const profil = await wajibPeran('penjual');
async function wajibPeran(peranDiizinkan) {
  const profil = await ambilProfil();
  if (!profil) {
    location.replace(AKAR + 'login.html');
    return null;
  }
  if (profil.status_akun !== 'aktif') {
    await db.auth.signOut();
    location.replace(AKAR + 'login.html?pesan=' + profil.status_akun);
    return null;
  }
  if (profil.peran !== peranDiizinkan) {
    location.replace(AKAR + HALAMAN_PERAN[profil.peran]);
    return null;
  }
  return profil;
}

async function keluar() {
  await db.auth.signOut();
  location.replace(AKAR + 'index.html');
}

function pasangHeader(denganKeluar = false) {
  const h = document.createElement('header');
  h.className = 'header';
  h.innerHTML = `<div class="container">
    <a class="merek" href="${AKAR}index.html">
      <img class="logo" src="${AKAR}img/logo-smkn1.png" alt="Logo SMK Negeri 1 Cimahi">
      <span>Kantin<br>SMKN 1 Cimahi</span>
    </a>
    ${denganKeluar ? '<button class="tombol tombol-garis" id="tombol-keluar">Keluar</button>' : ''}
  </div>`;
  const img = h.querySelector('img');
  img.onerror = () => {
    const kosong = document.createElement('span');
    kosong.className = 'logo-kosong';
    img.replaceWith(kosong);
  };
  document.body.prepend(h);
  if (denganKeluar) h.querySelector('#tombol-keluar').onclick = keluar;
}
