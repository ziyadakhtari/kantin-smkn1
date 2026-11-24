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

// Motion dan Lenis dipakai secara global karena proyek ini memakai HTML/JS biasa,
// bukan bundler. Jika CDN tidak tersedia, halaman dan kartu tetap berfungsi normal.
(() => {
  const mengurangiGerak = window.matchMedia('(prefers-reduced-motion: reduce)');
  if (mengurangiGerak.matches) return;

  function muatScript(src) {
    return new Promise((selesai, gagal) => {
      const sudahAda = document.querySelector(`script[src="${src}"]`);
      if (sudahAda) {
        sudahAda.addEventListener('load', selesai, { once: true });
        sudahAda.addEventListener('error', gagal, { once: true });
        return;
      }
      const script = document.createElement('script');
      script.src = src;
      script.async = true;
      script.onload = selesai;
      script.onerror = gagal;
      document.head.appendChild(script);
    });
  }

  function pasangLenis() {
    if (!window.Lenis || window.lenisKantin) return;
    const lenis = new window.Lenis({
      lerp: 0.09,
      smoothWheel: true,
      syncTouch: true,
      touchMultiplier: 1.2
    });
    window.lenisKantin = lenis;

    let bingkai;
    const animasiScroll = (waktu) => {
      lenis.raf(waktu);
      bingkai = requestAnimationFrame(animasiScroll);
    };
    bingkai = requestAnimationFrame(animasiScroll);

    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        cancelAnimationFrame(bingkai);
      } else {
        bingkai = requestAnimationFrame(animasiScroll);
      }
    });
  }

  function pasangMotion() {
    if (!window.Motion || window.motionKantinTerpasang) return;
    window.motionKantinTerpasang = true;

    const { animate, hover, inView } = window.Motion;
    const kartuSiap = new WeakSet();
    const kartuMasuk = new WeakSet();
    const pilihanKartu = '.kartu, .kartu-menu, .tiket';

    const naikkanKartu = (kartu) => animate(kartu, {
      y: -6,
      scale: 1.012,
      boxShadow: '0 16px 30px rgba(7, 42, 96, 0.14)'
    }, { duration: 0.22, easing: 'ease-out' });

    const turunkanKartu = (kartu) => animate(kartu, {
      y: 0,
      scale: 1,
      boxShadow: '0 0 0 rgba(7, 42, 96, 0)'
    }, { duration: 0.24, easing: 'ease-out' });

    function siapkanKartu(kartu, urutan = 0) {
      if (kartuSiap.has(kartu)) return;
      kartuSiap.add(kartu);
      kartu.classList.add('motion-card');

      inView(kartu, () => {
        if (kartuMasuk.has(kartu)) return;
        kartuMasuk.add(kartu);
        animate(kartu, { opacity: [0, 1], y: [20, 0] }, {
          duration: 0.46,
          delay: Math.min(urutan * 0.055, 0.28),
          easing: [0.22, 1, 0.36, 1]
        });
      }, { margin: '0px 0px -8% 0px' });

      hover(kartu, () => {
        naikkanKartu(kartu);
        return () => turunkanKartu(kartu);
      });

      kartu.addEventListener('focusin', () => naikkanKartu(kartu));
      kartu.addEventListener('focusout', (event) => {
        if (!kartu.contains(event.relatedTarget)) turunkanKartu(kartu);
      });
    }

    function cariKartu(akar = document) {
      const kartu = [];
      if (akar instanceof Element && akar.matches(pilihanKartu)) kartu.push(akar);
      if (akar.querySelectorAll) kartu.push(...akar.querySelectorAll(pilihanKartu));
      kartu.forEach(siapkanKartu);
    }

    cariKartu();
    new MutationObserver((perubahan) => {
      perubahan.forEach(({ addedNodes }) => addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE) cariKartu(node);
      }));
    }).observe(document.body, { childList: true, subtree: true });
  }

  const mulai = () => {
    muatScript('https://cdn.jsdelivr.net/npm/lenis@1.3.16/dist/lenis.min.js')
      .then(pasangLenis).catch(() => {});
    muatScript('https://cdn.jsdelivr.net/npm/motion@12.23.24/dist/motion.js')
      .then(pasangMotion).catch(() => {});
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mulai, { once: true });
  } else {
    mulai();
  }
})();
