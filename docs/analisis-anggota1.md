# Analisis Konsep Sistem Operasi — Anggota 1

**Penanggung jawab:** Afwan
**Modul:** `scripts/validation.sh`
**Skenario utama:** T01, T02, dan T03
**Pengujian tambahan:** V01–V06

## 1. Ruang Lingkup Modul

Modul validasi memeriksa dua parameter yang diberikan kepada program, yaitu lokasi sumber dan lokasi tujuan pencadangan. Pemeriksaan dilakukan sebelum proses pembuatan arsip dimulai. Modul ini tidak membuat arsip dan tidak melakukan pemulihan data.

## 2. Sistem Berkas dan Pemeriksaan Direktori

Modul menggunakan kondisi Bash untuk memeriksa lokasi yang diberikan pengguna.

- `-e` memeriksa apakah jalur yang diberikan tersedia.
- `-d` memeriksa apakah jalur tersebut merupakan direktori.

Pemeriksaan ini diperlukan karena suatu jalur dapat menunjuk ke berkas biasa, bukan direktori. Sumber pencadangan pada rancangan proyek harus berupa direktori yang berisi data uji.

## 3. Hak Akses dan Proteksi

Modul memeriksa hak akses berdasarkan identitas pengguna yang menjalankannya.

- `-r` memeriksa apakah direktori sumber dapat dibaca.
- `-x` pada direktori memeriksa izin penelusuran, yaitu kemampuan untuk mengakses isi atau nama di dalam direktori.
- `-w` memeriksa apakah direktori tujuan dapat ditulisi.

Pengujian menggunakan akun non-root diperlukan agar hasil pemeriksaan mencerminkan hak akses pengguna biasa. Akun `root` memiliki hak khusus sehingga tidak tepat digunakan sebagai satu-satunya akun pengujian permission.

## 4. Parameter, Percabangan, dan Penanganan Kesalahan

Skrip menerima tepat dua parameter. Variabel `$1` menyimpan lokasi sumber, sedangkan `$2` menyimpan lokasi tujuan. Variabel `$#` digunakan untuk menghitung jumlah parameter.

Percabangan `if` dan kondisi `[[ ... ]]` digunakan untuk memeriksa jumlah parameter, nilai kosong, keberadaan jalur, jenis direktori, serta hak akses. Jika suatu pemeriksaan gagal, skrip menampilkan pesan yang sesuai dan berhenti dengan `exit`.

## 5. Proses dan Exit Status

Skrip validasi dijalankan sebagai proses Bash. Proses pemanggil dapat membaca hasilnya melalui *exit status*.

| Exit status | Makna pada modul |
|---:|---|
| 0 | Validasi berhasil |
| 2 | Jumlah parameter salah atau parameter kosong |
| 3 | Sumber tidak tersedia atau bukan direktori |
| 4 | Sumber tidak dapat diakses |
| 5 | Tujuan tidak tersedia atau bukan direktori |
| 6 | Tujuan tidak dapat ditulis |

Kode tersebut merupakan kesepakatan internal modul ini, bukan kode kesalahan universal Linux. Modul backup harus menghentikan proses ketika validasi menghasilkan status selain `0`.

## 6. Hubungan dengan Modul Backup

Validasi menjadi pemeriksaan awal sebelum pembuatan arsip. Jika sumber atau tujuan tidak memenuhi persyaratan, modul backup tidak boleh dilanjutkan. Walaupun validasi berhasil, pembuatan arsip masih dapat gagal karena masalah lain, misalnya ruang penyimpanan tidak cukup atau kesalahan operasi I/O. Karena itu, modul pembuatan arsip tetap harus memiliki penanganan kesalahan sendiri.

## 7. Keterbatasan

Pemeriksaan hak akses menggambarkan keadaan pada saat validasi dilakukan. Kondisi direktori atau hak akses dapat berubah sebelum proses backup benar-benar berjalan. Oleh sebab itu, hasil validasi bukan jaminan bahwa operasi berikutnya pasti berhasil. Pemeriksaan pada modul backup tetap diperlukan ketika operasi tulis benar-benar dilakukan.

## 8. Lingkungan dan Status Pengujian

Pengujian awal dilakukan secara lokal pada CachyOS menggunakan Bash, termasuk pengujian dengan akun non-root `validationtester`. Pengujian akhir pada Ubuntu Server sebagai lingkungan implementasi kelompok masih harus dilakukan dan dicatat secara terpisah.
