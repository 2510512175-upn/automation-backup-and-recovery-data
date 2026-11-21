# Portofolio Individu — Project Akhir Sistem Operasi & Praktikum Sistem Operasi

## 1. Identitas Mahasiswa

* **Nama Lengkap:** Muhammad Afaf Kafabillah
* **NIM:** 2510512175
* **Program Studi:** S1 Sistem Informasi — Fakultas Ilmu Komputer UPN "Veteran" Jakarta
* **Kelompok:** Kelompok 1
* **Pilihan Proyek:** 5A — Sistem Otomasi Backup dan Pemulihan Data Linux
* **Peran:** Anggota 3 (Modul Pembuatan & Verifikasi Integritas Checksum SHA-256)

---

## 2. Asal Proyek & Tim

* **Repository Utama Kelompok:** (https://github.com/Kelompok-1-Project-5A-Kelas-E/automation-backup-and-recovery-data)
* **Commit Acuan Repository Utama:** (https://github.com/Kelompok-1-Project-5A-Kelas-E/automation-backup-and-recovery-data/tree/main)
* **Anggota Kelompok:**
  1. Muhamad Afwan Imam Nasuha — Validasi sumber dan parameter
  2. Muhammad Agung Budi Laksono — Pembuatan arsip dan pengaturan hak akses
  3. Muhammad Afaf Kafabillah — Pembuatan dan verifikasi integritas checksum SHA-256
  4. Panggi Hidayah — Pemulihan data (restore)
  5. Muhammad Nur Ihsani Izzul Haq Rosyid — Lock, log, laporan, dan Docker
  6. Muhammad Rafif Husein Salam — Pengelolaan data uji serta monitoring CPU, memori, dan proses

---

## 3. Kontribusi Pribadi

Pada proyek kelompok ini, saya bertanggung jawab merancang, mengimplementasikan, dan menguji modul verifikasi integritas berkas cadangan menggunakan algoritma **SHA-256** pada `scripts/verify.sh`:

1. **Mode Pembuatan Checksum (`generate` / `create`):** Menghitung nilai *digest* SHA-256 dari berkas arsip `.tar.gz` menggunakan utilitas `sha256sum` dan menyimpannya ke berkas pendamping `.sha256`.
2. **Mode Verifikasi Integritas (`verify` / `check`):** Membaca nilai *digest* acuan pada baris pertama berkas `.sha256`, menghitung ulang *digest* aktual dari berkas arsip, lalu membandingkan keduanya sebelum proses pemulihan (`restore.sh`) dijalankan.
3. **Pembatasan Hak Akses Berkas Checksum:** Menerapkan `umask 077` serta `chmod 600` pada berkas `.sha256` agar hanya pemilik sah yang memiliki izin baca dan tulis (`-rw-------`).
4. **Kontrak Exit Status Antarmodul:** Mengembalikan `exit status 0` jika pembuatan checksum berhasil atau nilai hash cocok, `exit status 1` jika arsip berubah/rusak atau berkas tidak dapat diakses, serta `exit status 2` jika jumlah parameter atau mode perintah tidak valid.

---

## 4. Bukti Kontribusi Git

* **Commit Implementasi Modul:** `ea4f1cd` (`feat(verify): tambahkan skrip pembuatan dan verifikasi checksum SHA-256`)
* **Berkas yang Dibuat / Dikontribusikan:**
  * `scripts/verify.sh`
  * `docs/analisis-anggota3.md`
  * `tests/anggota3-verifikasi.md`
  * `evidence/anggota3-verifikasi.txt`

---

## 5. Skenario Pengujian Individu

### Skenario A: Verifikasi Arsip Asli (Kondisi Positif — T06)

* **Tujuan:** Memastikan arsip `.tar.gz` yang utuh dan tidak dimodifikasi lolos verifikasi integritas SHA-256.
* **Perintah:**
  ```bash
  ./scripts/verify.sh generate backup_uji.tar.gz
  ./scripts/verify.sh verify backup_uji.tar.gz
  echo $?

---

* **Hasil Aktual:** Nilai checksum acuan dan aktual identik (`a019235b4a1e8132e9b60566c17b39a7904297b07c38d1a68c704923f6494a9e`), terminal menampilkan `VERIFIKASI BERHASIL! Checksum cocok.`, dan keluaran menghasilkan `exit status 0`.[cite: 20, 38]

### Skenario B: Deteksi Perubahan / Manipulasi Arsip (Kondisi Negatif — T07)[cite: 20]

* **Tujuan:** Memastikan sistem mampu mendeteksi perubahan sekecil apa pun pada isi arsip dan menolak proses validasi.[cite: 20]
* **Langkah & Perintah:**
  1. Menyalin arsip asli beserta berkas `.sha256`-nya, lalu menambahkan teks `modifikasi_ilegal` ke akhir salinan arsip tanpa memperbarui berkas checksum.[cite: 20]
  2. Menjalankan pemeriksaan integritas:
     ```bash
     ./scripts/verify.sh verify backup_rusak.tar.gz
     echo $?
     ```
* **Hasil Aktual:** Nilai checksum aktual berubah menjadi `9b855514af8bb19308ca4253d50be4c0ece6ea8ca007700d693a830bfaf60f03` (tidak cocok dengan acuan), terminal menampilkan `VERIFIKASI GAGAL! Checksum tidak cocok (arsip berubah/rusak).`, dan skrip keluar dengan `exit status 1`.[cite: 20, 38]

### Skenario C: Validasi Parameter dan Pengamanan Izin Akses[cite: 35, 36]

* **Tujuan:** Memastikan berkas `.sha256` terlindungi izin `600` dan skrip menolak argumen perintah yang salah.[cite: 35, 36]
* **Hasil Aktual:** Pemeriksaan `ls -l` menunjukkan izin berkas `.sha256` tercatat `-rw-------` (`600`), sedangkan pemanggilan `./scripts/verify.sh` tanpa argumen menampilkan petunjuk penggunaan dan menghasilkan `exit status 2`.[cite: 35, 36]

---

## 6. Analisis Konsep Sistem Operasi[cite: 23, 24]

* **Integritas Data & Sistem Berkas (I/O):** Utilitas `sha256sum` membaca aliran *byte* berkas arsip dari sistem berkas untuk menghasilkan *hash* 256-bit yang bersifat deterministik. Perubahan satu karakter saja pada arsip menghasilkan *digest* yang berbeda total (*avalanche effect*), sehingga korupsi data akibat kegagalan I/O atau modifikasi tidak sah dapat dideteksi sebelum ekstraksi.[cite: 23]
* **Proses & Komunikasi Antarproses (IPC via Exit Status):** Skrip `verify.sh` berjalan sebagai proses anak yang dipanggil oleh `restore.sh`. Komunikasi keputusan antarproses dilakukan melalui mekanisme *exit status* standar POSIX (`0` untuk sukses/valid, bukan nol untuk gagal), sehingga `restore.sh` dapat langsung menghentikan eksekusi tanpa mengekstrak arsip rusak.[cite: 13, 24]
* **Proteksi & Kontrol Akses Berkas:** Penggunaan `umask 077` dan `chmod 600` memanfaatkan model izin akses Linux (*user-group-others*) untuk membatasi hak baca dan tulis berkas checksum hanya kepada pemilik proses, mencegah pengguna lain memanipulasi nilai checksum acuan.[cite: 10, 24, 35, 36]

---

## 7. Kendala & Penyelesaian

* **Kendala 1 (Potensi Karakter Kosong / Spasi pada Berkas Checksum):** Pembacaan baris dari berkas `.sha256` berisiko menyertakan karakter spasi atau baris baru (*newline*) yang membuat perbandingan string gagal meskipun nilai hash sebenarnya sama.
  * **Penyelesaian:** Mengambil kolom pertama menggunakan `awk 'NR==1 {print $1}'` yang dipadukan dengan `tr -d '[:space:]'` serta memvalidasi variabel tidak kosong (`[ -z "$EXPECTED_HASH" ]`) sebelum membandingkan digest.[cite: 37]
* **Kendala 2 (Penguncian Paket `dpkg` saat Pengujian di Lingkungan Ubuntu Server VM):** Saat menyiapkan lingkungan uji pada VM Ubuntu Server, instalasi utilitas pendukung sempat tertahan oleh proses pembaruan latar belakang sistem (`unattended-upgr`) yang mengunci `/var/lib/dpkg/lock-frontend`.[cite: 39, 43]
  * **Penyelesaian:** Menunggu antrean kunci paket secara aman menggunakan opsi `-o DPkg::Lock::Timeout=-1` tanpa menghapus berkas *lock* secara paksa sehingga integritas manajer paket sistem tetap terjaga.[cite: 39, 43]

---

## 8. Refleksi Pembelajaran

* **Hal yang Dikuasai:** Perancangan antarmuka skrip Bash yang modular dengan kontrak *exit status* yang konsisten (`0`, `1`, `2`), penerapan `set -Eeuo pipefail` untuk penanganan eror ketat, serta verifikasi integritas kriptografis menggunakan `sha256sum`.[cite: 35, 36, 37, 38]
* **Hal yang Perlu Dipelajari Lebih Lanjut:** Otomasi verifikasi integritas secara terjadwal menggunakan *systemd timer* atau *cron* serta penerapan tanda tangan digital (*GPG signing*) agar keaslian berkas checksum juga terverifikasi secara kriptografis.
