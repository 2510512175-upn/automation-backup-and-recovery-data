# Analisis Implementasi Anggota 5 - Lock, Log, dan Laporan

## 1. Ruang lingkup

Bagian ini menangani tiga fungsi yang diintegrasikan ke dalam `scripts/backup.sh`:

1. Lock untuk mencegah dua proses backup berjalan bersamaan.
2. Log untuk mencatat aktivitas dan hasil proses backup.
3. Laporan untuk merangkum hasil backup yang berhasil.

Pembuatan arsip tetap menjadi bagian Agung. Pemeriksaan sumber dan tujuan tetap menggunakan `validation.sh` milik Afwan. Pembuatan serta verifikasi checksum tetap menggunakan `verify.sh` milik Afaf. Pengujian Docker read-only (T13-T14) tidak termasuk dalam perubahan ini.

## 2. Perancangan lock

Program membuat file `output/backup_5a.lock`, kemudian membuka file tersebut melalui file descriptor 200. Perintah `flock -n 200` mencoba memperoleh exclusive lock secara non-blocking.

- Jika lock berhasil diperoleh, proses melanjutkan validasi dan backup.
- Jika lock sedang dipegang proses lain, proses baru ditolak, mencatat pesan `ERROR` ke log, dan berakhir dengan exit status `1`.
- Lock tetap dipegang selama proses backup berjalan. Ketika proses berakhir, file descriptor ditutup dan kernel melepas lock.
- File lock tidak perlu dihapus. Menghapus file lock saat proses lain masih menggunakannya dapat membuat proses berikutnya mengunci inode yang berbeda.

Lokasi file lock berada pada direktori `output` milik proyek. Hal ini menghindari pemakaian satu file `/tmp/backup_5a.lock` oleh beberapa salinan proyek yang berbeda.

## 3. Perancangan log

Log disimpan pada `output/backup.log`. Setiap baris memiliki format:

```text
[YYYY-MM-DD HH:MM:SS] [PID:1234] [LEVEL] Pesan aktivitas
```

Tingkat pesan yang digunakan:

- `INFO` untuk aktivitas yang berhasil atau tahapan proses.
- `ERROR` untuk penolakan, kegagalan, atau kondisi yang menghentikan proses.

Log mencatat setidaknya keberhasilan memperoleh lock, penolakan akibat lock, hasil validasi, awal pembuatan arsip, pembuatan checksum, verifikasi checksum, dan hasil akhir backup. Pesan kegagalan juga disertai exit status jika tersedia.

## 4. Perancangan laporan

Laporan disimpan pada `output/laporan.txt` setelah arsip lolos pemeriksaan struktur dan checksum. Isi laporan mencakup:

- Nama atau path arsip.
- Waktu eksekusi.
- Checksum SHA-256 arsip.
- Hasil verifikasi.
- Status proses dan PID.

Laporan dibuat terlebih dahulu pada file sementara di direktori yang sama, lalu dipindahkan menjadi `laporan.txt`. Cara ini mencegah file laporan utama tertinggal dalam keadaan terpotong apabila proses penulisan gagal.

## 5. Lokasi file dan izin akses

Lokasi output ditentukan berdasarkan lokasi `backup.sh`, bukan berdasarkan direktori kerja terminal. Secara bawaan, file operasional berada di direktori `output` pada akar proyek.

`umask 077` diterapkan sebelum file operasional dibuat. Izin file lock, log, dan laporan juga diatur menjadi `600`, sehingga hanya pemilik file yang dapat membaca atau mengubahnya. Arsip backup tetap diatur oleh bagian pembuatan arsip dan memiliki izin `600`.

## 6. Hubungan dengan skenario pengujian

| ID | Tujuan | Cara pembuktian |
|---|---|---|
| T10 | Memastikan proses kedua ditolak ketika proses pertama sedang memegang lock | Jalankan pengujian otomatis `tests/test-izzul-lock-log-report.sh`, lalu periksa keluaran penolakan dan exit status proses kedua |
| T11 | Memastikan aktivitas dan hasil backup tercatat | Periksa `output/backup.log` untuk baris lock diperoleh, proses kedua ditolak, dan backup berhasil |
| T12 | Memastikan laporan berisi informasi backup | Periksa `output/laporan.txt`, lalu cocokkan nilai checksum dengan hasil `sha256sum` pada arsip |

Pengujian otomatis menggunakan pembungkus perintah `tar` pada salinan sementara proyek. Pembungkus menahan proses backup pertama selama beberapa detik agar proses kedua dapat dicoba ketika lock masih aktif. Script pengujian tidak mengubah script proyek asli maupun direktori `output` proyek.

## 7. Cara menjalankan

Dari direktori akar proyek:

```bash
bash tests/test-izzul-lock-log-report.sh
```

Untuk memeriksa log dan laporan dari proses backup normal:

```bash
cat output/backup.log
cat output/laporan.txt
```

Untuk mencocokkan checksum arsip dengan nilai pada laporan:

```bash
sha256sum "PATH_ARSIP_DARI_LAPORAN"
```

## 8. Bukti yang perlu disimpan pada VM Ubuntu kelompok

Simpan tangkapan layar atau keluaran terminal asli untuk:

1. Proses backup pertama sedang berjalan dan proses kedua ditolak oleh lock.
2. Baris log yang menunjukkan lock diperoleh, penolakan proses kedua, dan backup berhasil.
3. Isi `laporan.txt` yang menampilkan nama arsip, waktu, checksum, hasil verifikasi, dan status proses.
4. Hasil pencocokan checksum laporan dengan arsip.
5. Izin akses file operasional melalui `stat -c '%a %n' output/backup_5a.lock output/backup.log output/laporan.txt`.

Hasil pengujian dari salinan sementara hanya digunakan untuk memeriksa fungsi script. Hasil tersebut bukan pengganti bukti pengujian pada VM Ubuntu kelompok.
