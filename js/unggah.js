// unggah.js - mengecilkan gambar lalu mengunggahnya ke Supabase Storage.
// Foto dari HP sering 3-5 MB; di sini dikecilkan dulu supaya cepat dan di bawah batas 2 MB.

function kecilkanGambar(berkas, maxSisi = 1000, kualitas = 0.82) {
  return new Promise((selesai, gagal) => {
    const gambar = new Image();
    const url = URL.createObjectURL(berkas);
    gambar.onload = () => {
      URL.revokeObjectURL(url);
      const skala = Math.min(1, maxSisi / Math.max(gambar.width, gambar.height));
      const kanvas = document.createElement('canvas');
      kanvas.width = Math.round(gambar.width * skala);
      kanvas.height = Math.round(gambar.height * skala);
      const k = kanvas.getContext('2d');
      k.fillStyle = '#fff';               // latar putih (agar PNG transparan tidak jadi hitam)
      k.fillRect(0, 0, kanvas.width, kanvas.height);
      k.drawImage(gambar, 0, 0, kanvas.width, kanvas.height);
      kanvas.toBlob((b) => (b ? selesai(b) : gagal(new Error('Gambar gagal diproses.'))), 'image/jpeg', kualitas);
    };
    gambar.onerror = () => { URL.revokeObjectURL(url); gagal(new Error('File itu bukan gambar yang valid.')); };
    gambar.src = url;
  });
}

// Mengembalikan alamat (URL) gambar yang sudah diunggah
async function unggahGambar(uid, awalan, berkas, maxSisi, kualitas) {
  const blob = await kecilkanGambar(berkas, maxSisi, kualitas);
  const jalur = `${uid}/${awalan}-${Date.now()}.jpg`;
  const { error } = await db.storage.from('kantin').upload(jalur, blob, {
    contentType: 'image/jpeg', cacheControl: '31536000'
  });
  if (error) throw error;
  return db.storage.from('kantin').getPublicUrl(jalur).data.publicUrl;
}

// Menghapus gambar lama (kalau gagal, diabaikan saja)
async function hapusGambar(url) {
  const tanda = '/object/public/kantin/';
  const i = (url || '').indexOf(tanda);
  if (i < 0) return;
  try { await db.storage.from('kantin').remove([decodeURIComponent(url.slice(i + tanda.length))]); } catch (e) {}
}
