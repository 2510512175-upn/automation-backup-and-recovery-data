# Bukti Pengujian Modul Validasi — Afwan

Folder ini berisi tangkapan layar pengujian modul `scripts/validation.sh`.

## 1. Daftar Bukti Pengujian

| Berkas Bukti | Isi Bukti | Skenario |
|---|---|---|
| `Screenshot_20261114_165124.png` | Direktori sumber dan tujuan valid diterima | T01 |
| `Screenshot_20261114_165133.png` | Sumber tidak tersedia ditolak dengan exit status 3 | T02 |
| `Screenshot_20261114_165157.png` | Parameter tidak diberikan, parameter kosong, dan direktori tujuan tidak ditemukan | T03, V01, V03 |
| `V02-sumber-bukan-direktori.png` | Sumber berupa berkas biasa ditolak dengan exit status 3 | V02 |
| `Screenshot_20261114_165206.png` | Bukti pemeriksaan permission sumber dan tujuan pada pengujian lokal | Pendukung |
| `Screenshot_uji_nonroot_valid_dan_tujuan.png` | Akun `validationtester` berhasil menggunakan direktori valid dan ditolak saat tujuan tidak dapat ditulis | V04, V06 |
| `Screenshot_uji_nonroot_sumber.png` | Akun `validationtester` ditolak saat sumber tidak dapat diakses | V05 |
| `Screenshot_pemeriksaan_sintaks_dan_eksekusi.png` | Pemeriksaan sintaks Bash dan eksekusi langsung modul | Pemeriksaan sintaks dan eksekusi |

## 2. Catatan Pengujian

1. Pengujian awal dilakukan pada CachyOS menggunakan Bash.
2. Pengujian hak akses dilakukan menggunakan akun non-root `validationtester`.
3. Tangkapan layar merupakan bukti pendukung. Perintah, hasil aktual, dan exit status dicatat dalam `tests/anggota1-uji-validasi.md`.
4. Pengujian V02 telah diulang menggunakan versi skrip terbaru dan menghasilkan pesan `Sumber bukan direktori` dengan exit status 3.
5. Seluruh pengujian harus direproduksi kembali pada Ubuntu Server sebagai lingkungan implementasi kelompok.

## 3. Status Dokumentasi

Bukti pengujian lokal modul validasi telah dikumpulkan. Pengujian akhir pada Ubuntu Server masih harus dilakukan sebelum modul dinyatakan selesai di lingkungan implementasi kelompok.
