// keranjang.js - keranjang belanja pembeli (disimpan di browser) + menu bawah.
// Butuh: guard.js (untuk AKAR). Keranjang dipisah per akun.
// Harga di sini hanya untuk TAMPILAN. Harga sebenarnya dihitung ulang database saat pesan.

const KUNCI_KERANJANG = 'keranjang-kantin';
let uidKeranjang = null;

async function siapkanKeranjang() {
  const { data: { session } } = await db.auth.getSession();
  uidKeranjang = session.user.id;
}

function bacaKeranjang() {
  try {
    const k = JSON.parse(localStorage.getItem(KUNCI_KERANJANG));
    if (k && k.uid === uidKeranjang && Array.isArray(k.item)) return k;
  } catch (e) {}
  return { uid: uidKeranjang, kantinId: null, kantinNama: '', item: [] };
}

function simpanKeranjang(k) {
  try { localStorage.setItem(KUNCI_KERANJANG, JSON.stringify(k)); } catch (e) {}
  perbaruiLencana();
}

function jumlahItem(k = bacaKeranjang()) { return k.item.reduce((a, i) => a + i.jumlah, 0); }
function totalHarga(k = bacaKeranjang()) { return k.item.reduce((a, i) => a + i.harga * i.jumlah, 0); }

function kosongkanKeranjang() {
  simpanKeranjang({ uid: uidKeranjang, kantinId: null, kantinNama: '', item: [] });
}

// Hasil: 'ok' | 'stok' (sudah mencapai batas) | 'beda-kantin'
function tambahKeKeranjang(menu, kantin) {
  const k = bacaKeranjang();
  if (k.item.length && k.kantinId !== kantin.id) return 'beda-kantin';
  k.kantinId = kantin.id;
  k.kantinNama = kantin.nama_kantin;
  const ada = k.item.find((x) => x.id === menu.id);
  if (ada) {
    if ((menu.stok !== null && ada.jumlah >= menu.stok) || ada.jumlah >= 50) return 'stok';
    ada.jumlah += 1;
    ada.stok = menu.stok;
  } else {
    k.item.push({ id: menu.id, nama: menu.nama, harga: menu.harga, jumlah: 1, foto: menu.foto_url, stok: menu.stok });
  }
  simpanKeranjang(k);
  return 'ok';
}

// Mengubah jumlah (delta +1 / -1). Jumlah 0 = item dihapus. Mengembalikan false bila melewati batas.
function ubahJumlah(id, delta) {
  const k = bacaKeranjang();
  const it = k.item.find((x) => x.id === id);
  if (!it) return false;
  const baru = it.jumlah + delta;
  if (baru > 0 && ((it.stok !== null && baru > it.stok) || baru > 50)) return false;
  if (baru <= 0) k.item = k.item.filter((x) => x.id !== id);
  else it.jumlah = baru;
  if (!k.item.length) { k.kantinId = null; k.kantinNama = ''; }
  simpanKeranjang(k);
  return true;
}

function hapusItem(id) {
  const k = bacaKeranjang();
  k.item = k.item.filter((x) => x.id !== id);
  if (!k.item.length) { k.kantinId = null; k.kantinNama = ''; }
  simpanKeranjang(k);
}

// Menu navigasi di bagian bawah layar (nyaman untuk HP)
function pasangNavPembeli(aktif) {
  const gaya = document.createElement('style');
  gaya.textContent = `
    .nav-bawah{position:fixed;left:0;right:0;bottom:0;display:flex;background:#fff;border-top:1px solid var(--garis);z-index:20}
    .nav-bawah a{flex:1;text-align:center;padding:16px 8px;font-weight:700;color:var(--lembut);text-decoration:none}
    .nav-bawah a.aktif{color:var(--utama);box-shadow:inset 0 3px 0 var(--aksen)}
    .lencana{display:inline-block;min-width:22px;padding:0 6px;border-radius:99px;background:var(--aksen);color:#2b1300;font-size:.8rem}
    .toast-area{bottom:84px}`;
  document.head.appendChild(gaya);
  const nav = document.createElement('nav');
  nav.className = 'nav-bawah';
  nav.innerHTML = `
    <a href="${AKAR}pembeli/kantin.html" class="${aktif === 'kantin' ? 'aktif' : ''}">Kantin</a>
    <a href="${AKAR}pembeli/keranjang.html" class="${aktif === 'keranjang' ? 'aktif' : ''}">Keranjang <span id="lencana" class="lencana" hidden></span></a>`;
  document.body.appendChild(nav);
  document.body.style.paddingBottom = '72px';
  perbaruiLencana();
}

function perbaruiLencana() {
  const l = document.getElementById('lencana');
  if (!l) return;
  const n = jumlahItem();
  l.textContent = n;
  l.hidden = n === 0;
}
