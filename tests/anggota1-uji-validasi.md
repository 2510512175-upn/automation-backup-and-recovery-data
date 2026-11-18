# Pengujian Anggota 1: Validasi Sumber dan Parameter

**Penanggung jawab:** Afwan
**Modul:** `scripts/validation.sh`
**Lingkungan pengujian awal:** CachyOS, Bash
**Akun pengujian:** akun utama dan akun non-root `validationtester`

## 1. Tujuan Pengujian

Memastikan modul validasi menerima sumber dan tujuan yang memenuhi persyaratan, serta menolak parameter atau jalur yang tidak sesuai sebelum proses pembuatan arsip dijalankan.

## 2. Pengujian Utama Sesuai Matriks Kelompok

| Item | T01 (positif) | T02 (negatif) | T03 (negatif) |
|---|---|---|---|
| Tujuan | Sumber valid dan dapat dibaca diterima | Sumber tidak tersedia ditolak | Parameter wajib yang tidak diberikan ditolak |
| Langkah | Jalankan `validation.sh` dengan direktori sumber dan tujuan yang valid | Jalankan skrip dengan sumber yang tidak tersedia | Jalankan skrip tanpa memberikan dua parameter |
| Hasil yang diharapkan | Validasi berhasil | Pesan penolakan dan exit status bukan nol | Ditolak sebelum proses backup |
| Hasil aktual | Pesan `Validasi berhasil` tampil | Sumber ditolak dengan exit status `3` | Parameter ditolak dengan exit status `2` |
| Status | Lulus | Lulus | Lulus |
| Bukti | `Screenshot_20261114_165124.png` | `Screenshot_20261114_165133.png` | `Screenshot_20261114_165157.png` |

Catatan T01: tangkapan layar awal menampilkan pesan keberhasilan, tetapi tidak menampilkan perintah untuk mencetak exit status. Pengujian positif tambahan menggunakan akun non-root yang mencetak status `0` dicatat sebagai V04.

## 3. Pengujian Tambahan

Pengujian berikut melengkapi skenario utama. Kode V digunakan agar tidak bertabrakan dengan ID T01–T18 pada matriks pengujian kelompok.

| ID | Skenario | Hasil aktual | Exit status | Status |
|---|---|---|---:|---|
| V01 | Parameter kosong | Ditolak dengan pesan parameter kosong | 2 | Lulus |
| V02 | Sumber berupa berkas biasa, bukan direktori | Ditolak dengan pesan sumber bukan direktori | 3 | Lulus |
| V03 | Direktori tujuan tidak ditemukan | Ditolak dengan pesan tujuan tidak ditemukan | 5 | Lulus |
| V04 | Akun non-root menggunakan sumber dan tujuan yang valid | Validasi berhasil | 0 | Lulus |
| V05 | Akun non-root mengakses sumber tanpa izin baca dan penelusuran | Ditolak dengan pesan sumber tidak dapat diakses | 4 | Lulus |
| V06 | Akun non-root menggunakan tujuan tanpa izin tulis | Ditolak dengan pesan tujuan tidak dapat ditulis | 6 | Lulus |

## 4. Prosedur Pengujian Akun Non-root

Pengujian lokal menggunakan akun `validationtester`, bukan `root`. Kepemilikan direktori tujuan positif diberikan kepada akun penguji agar direktori dapat ditulisi. Untuk pengujian negatif, izin sumber atau tujuan diubah sementara sesuai skenario.

Contoh pemeriksaan identitas akun:

```bash
sudo -u validationtester whoami
```

Contoh menjalankan modul sebagai akun penguji:

```bash
sudo -u validationtester bash /tmp/validation.sh \
  /tmp/validation-test/source-valid \
  /tmp/validation-test/destination
```

## 5. Pemeriksaan Sintaks dan Eksekusi

Pemeriksaan sintaks dilakukan menggunakan:

```bash
bash -n scripts/validation.sh
```

Skrip juga dijalankan langsung setelah izin eksekusi diberikan menggunakan `chmod +x`. Pemeriksaan sintaks tidak menampilkan pesan ketika tidak ditemukan kesalahan sintaks.

## 6. Bukti Pengujian

Daftar tangkapan layar dan kaitannya dengan setiap skenario dicantumkan pada `evidence/01-validation/README.md`.

## 7. Kesimpulan dan Tindak Lanjut

Pengujian awal menunjukkan bahwa modul validasi
dapat menerima input valid dan menolak kondisi
parameter, direktori, serta hak akses yang tidak
sesuai.

Pengujian tambahan V01–V06 juga telah dilaksanakan,
termasuk pengujian menggunakan akun non-root.

Seluruh pengujian lokal menunjukkan hasil sesuai
dengan yang diharapkan. Pengujian akhir tetap perlu
direproduksi pada Ubuntu Server sebagai lingkungan
implementasi kelompok.