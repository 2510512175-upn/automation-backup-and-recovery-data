# Analisis Sistem Operasi - Anggota 4
## Modul Pemulihan Data (Data Recovery)

### 1. Konsep Pemulihan Data

Modul pemulihan data merupakan bagian dari sistem otomasi backup dan pemulihan data Linux. Modul ini bertugas mengembalikan data dari arsip backup ke direktori tujuan pengujian.

Sebelum ekstraksi dilakukan, sistem memverifikasi integritas arsip menggunakan checksum SHA-256 melalui modul `verify.sh`.

### 2. Interaksi Antarproses

Modul `restore.sh` memanggil `verify.sh` sebagai proses terpisah menggunakan perintah Bash.

Komunikasi antara kedua proses dilakukan melalui exit status.

- Exit status `0` menunjukkan checksum cocok.
- Exit status `1` menunjukkan verifikasi gagal.
- Proses pemulihan hanya dilanjutkan apabila verifikasi berhasil.

Mekanisme ini menunjukkan penggunaan status keluar proses sebagai bentuk komunikasi antarprogram dalam sistem Linux.

### 3. Operasi Input dan Output

Pada proses recovery, GNU Tar membaca arsip backup dari sistem berkas dan mengekstrak data ke direktori sementara.

Proses tersebut melibatkan:
- Operasi baca terhadap file arsip.
- Operasi tulis terhadap file hasil ekstraksi.
- Pembuatan direktori sementara.
- Pemindahan hasil ekstraksi ke direktori tujuan.

### 4. Penggunaan Direktori Sementara

Modul menggunakan `mktemp` untuk membuat direktori sementara sebagai lokasi ekstraksi.

Tujuannya adalah mencegah hasil ekstraksi parsial langsung tercampur dengan direktori tujuan apabila terjadi kegagalan.

Setelah ekstraksi selesai, data dipindahkan ke direktori tujuan. Direktori sementara kemudian dibersihkan.

### 5. Integritas Data dengan SHA-256

SHA-256 digunakan untuk memastikan arsip tidak mengalami perubahan sejak checksum dibuat.

Jika isi arsip berubah, nilai checksum aktual akan berbeda dari checksum acuan.

Dalam pengujian T09, perubahan data pada arsip menghasilkan checksum berbeda sehingga sistem menolak proses recovery.

### 6. Penanganan Kesalahan

Sistem menggunakan exit status untuk membedakan keberhasilan dan kegagalan operasi.

Beberapa kondisi yang ditangani meliputi:
- Arsip tidak ditemukan.
- File checksum tidak tersedia.
- Checksum tidak cocok.
- Arsip tidak dapat dibaca.
- Struktur arsip tidak valid.
- Proses ekstraksi gagal.

### 7. Hasil Pengujian

**T08 — Pemulihan Arsip Valid**

Arsip valid berhasil dipulihkan dengan exit status `0`. Perbandingan menggunakan `diff -r` tidak menemukan perbedaan antara data sumber dan data hasil pemulihan.

**T09 — Penolakan Arsip Rusak**

Arsip yang dimodifikasi berhasil terdeteksi melalui perbedaan checksum. Sistem menolak proses recovery dengan exit status `1` dan direktori hasil tetap kosong.

### 8. Kesimpulan

Modul pemulihan menerapkan prinsip pemeriksaan integritas sebelum pemulihan data.

Integrasi antara Bash, GNU Tar, SHA-256sum, direktori sementara, dan exit status memungkinkan proses pemulihan dilakukan secara lebih terkendali.

Pengujian membuktikan bahwa modul dapat memulihkan arsip valid dan menolak arsip yang integritasnya tidak sesuai.
