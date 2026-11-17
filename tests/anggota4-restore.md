
# Pengujian Modul Pemulihan Data - Anggota 4

## 1. Tujuan Pengujian

Pengujian dilakukan untuk memastikan modul restore.sh dapat:
1. Memulihkan arsip backup yang valid.
2. Memeriksa integritas arsip menggunakan SHA-256.
3. Menolak arsip yang telah dimodifikasi.
4. Memastikan data hasil pemulihan sesuai dengan data sumber.

## 2. Lingkungan Pengujian

- Sistem Operasi: CachyOS Linux
- Shell: Fish
- Interpreter: Bash
- Utilitas: GNU Tar, SHA-256sum
- Modul: scripts/restore.sh
- Modul verifikasi: scripts/verify.sh

## 3. Kasus Uji T08 - Pemulihan Arsip Valid

### Tujuan
Memastikan sistem dapat memulihkan arsip backup yang memiliki checksum valid.

### Data Pengujian

Direktori sumber:
- dokumen/data.txt
- informasi.txt

Isi data:
- "Data pengujian recovery"
- "Anggota 4 - Sistem Operasi"

### Langkah Pengujian

1. Membuat direktori sumber, arsip, dan hasil pemulihan.
2. Membuat dua file dummy sebagai data sumber.
3. Menjalankan scripts/backup.sh.
4. Membuat checksum menggunakan scripts/verify.sh generate.
5. Menjalankan scripts/restore.sh.
6. Membandingkan direktori sumber dan hasil pemulihan menggunakan diff -r.

### Hasil yang Diharapkan

- Arsip berhasil diverifikasi.
- Proses ekstraksi berhasil.
- Pemulihan dinyatakan berhasil.
- Data hasil pemulihan identik dengan data sumber.
- Exit status bernilai 0.

### Hasil Aktual

- Pembuatan arsip berhasil.
- Checksum SHA-256 berhasil dibuat.
- Verifikasi checksum berhasil.
- Pemulihan data berhasil.
- Perintah diff -r tidak menemukan perbedaan.
- Exit status recovery: 0.
- Exit status perbandingan data: 0.

### Kesimpulan

T08 dinyatakan LULUS karena arsip valid berhasil dipulihkan dan hasilnya identik dengan data sumber.

---

## 4. Kasus Uji T09 - Penolakan Arsip Rusak

### Tujuan

Memastikan sistem menolak arsip yang mengalami perubahan setelah checksum dibuat.

### Langkah Pengujian

1. Menyalin arsip backup dan file checksum asli.
2. Memodifikasi arsip dengan menambahkan teks DATA_RUSAK.
3. Menyiapkan direktori hasil pemulihan.
4. Menjalankan scripts/restore.sh terhadap arsip yang telah dimodifikasi.
5. Memeriksa exit status.
6. Memastikan direktori hasil pemulihan tetap kosong.

### Hasil yang Diharapkan

- Checksum aktual berbeda dari checksum acuan.
- Sistem menolak arsip.
- Ekstraksi tidak dilakukan.
- Exit status bernilai 1.

### Hasil Aktual

Checksum acuan:
8e3a98354e41c844d5063355830d696b3ecadc068eeb10ef6ddcadcc369105bc

Checksum aktual:
7a400ed3c8c7fd1c59750587204e38f127f4b0a68cb7299880f8b88b1649a51e

Pesan sistem:
VERIFIKASI GAGAL! Checksum tidak cocok (arsip berubah/rusak).

ERROR: Arsip ditolak karena verifikasi checksum gagal.

Exit status: 1.

Direktori hasil pemulihan tetap kosong berdasarkan pemeriksaan menggunakan find.

### Kesimpulan

T09 dinyatakan LULUS karena sistem berhasil mendeteksi perubahan arsip dan menolak pemulihan sebelum ekstraksi dilakukan.

---

## 5. Kesimpulan Umum

Berdasarkan pengujian T08 dan T09, modul pemulihan data berhasil menjalankan fungsi utama sesuai rancangan.

Modul dapat memulihkan arsip dengan integritas yang valid serta menolak arsip yang mengalami perubahan berdasarkan verifikasi SHA-256.

Penggunaan exit status memungkinkan modul pemulihan mengetahui keberhasilan atau kegagalan proses verifikasi dari modul Anggota 3.
