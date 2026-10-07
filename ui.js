// ui.js - fungsi bantu yang dipakai semua halaman.

// 12000 -> "Rp 12.000"
function rupiah(angka) {
  return 'Rp ' + Number(angka || 0).toLocaleString('id-ID');
}

// Wajib dipakai saat menampilkan teks buatan pengguna (nama, catatan, dll.)
// ke dalam HTML, supaya tidak dibaca sebagai kode.
function aman(teks) {
  const peta = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  return String(teks ?? '').replace(/[&<>"']/g, (c) => peta[c]);
}

// Pesan singkat di bawah layar. jenis: '' | 'sukses' | 'gagal'
function tampilToast(pesan, jenis = '') {
  let area = document.querySelector('.toast-area');
  if (!area) {
    area = document.createElement('div');
    area.className = 'toast-area';
    area.setAttribute('role', 'status');
    document.body.appendChild(area);
  }
  const t = document.createElement('div');
  t.className = 'toast ' + jenis;
  t.textContent = pesan;
  area.appendChild(t);
  setTimeout(() => t.remove(), 3500);
}

function tampilLoading(el) {
  el.innerHTML = '<div class="putar" role="status" aria-label="Memuat"></div>';
}

function tampilKosong(el, judul, keterangan = '') {
  el.innerHTML = `<div class="kosong"><strong>${aman(judul)}</strong>${aman(keterangan)}</div>`;
}

// Matikan tombol selama proses berjalan agar tidak terklik dua kali.
function tombolSibuk(tombol, sibuk, teksSibuk = 'Memproses...') {
  if (sibuk) {
    tombol.dataset.teksAsli = tombol.textContent;
    tombol.textContent = teksSibuk;
  } else if (tombol.dataset.teksAsli) {
    tombol.textContent = tombol.dataset.teksAsli;
  }
  tombol.disabled = sibuk;
}
