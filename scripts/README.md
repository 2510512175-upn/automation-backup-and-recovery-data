# Daftar Script

Direktori ini berisi Shell Script untuk menjalankan setiap bagian sistem.

| Nama file | Penanggung jawab | Fungsi |
|---|---|---|
| `validation.sh` | Afwan | Memvalidasi sumber, tujuan, dan parameter sebelum backup dijalankan. |
| `backup.sh` | Agung dan Izzul | Membuat arsip backup bertanggal, menerapkan pembatasan akses arsip, mengelola lock, mencatat log, dan menghasilkan laporan backup. |
| `verify.sh` | Afaf | Membuat dan memeriksa checksum arsip. |
| `restore.sh` | Panggi | Memeriksa arsip dan memulihkan data ke direktori pengujian. |
| `monitoring.sh` | Rafif | Mengamati penggunaan CPU dan memori sistem serta metrik proses berdasarkan PID. |

## Pengelolaan lock, log, dan laporan

Fungsi lock, log, dan laporan Izzul diintegrasikan ke dalam `backup.sh`, bukan berada pada file `lock.sh` atau `report.sh` terpisah.

- `output/backup_5a.lock` digunakan oleh `flock` untuk mencegah dua proses backup berjalan bersamaan.
- `output/backup.log` mencatat waktu, PID, tingkat pesan, dan aktivitas atau hasil proses backup.
- `output/laporan.txt` memuat nama arsip, waktu eksekusi, checksum SHA-256, hasil verifikasi, dan status proses.
- Direktori `output` ditentukan berdasarkan lokasi proyek. Jadi, lokasi log dan laporan tidak berubah ketika script dijalankan dari direktori terminal yang berbeda.
- File lock, log, dan laporan dibuat dengan izin pemilik saja (`600`) melalui `umask 077` dan pengaturan izin eksplisit.
- File lock tidak dihapus setelah proses selesai. `flock` melepas kunci ketika file descriptor 200 ditutup saat proses berakhir.

Jalankan pengujian T10-T12 dengan:

```bash
bash tests/test-izzul-lock-log-report.sh
```


## Monitoring CPU, memori, dan proses

Dari akar proyek, gunakan perintah berikut:

```bash
# Snapshot penggunaan CPU dan memori sistem
bash scripts/monitoring.sh

# Pemantauan sistem berulang setiap 5 detik
bash scripts/monitoring.sh --watch

# Mengambil satu sampel proses berdasarkan PID
bash scripts/monitoring.sh --pid PID

# Memantau PID setiap 1 detik sampai proses selesai
bash scripts/monitoring.sh --watch-pid PID
```

Log monitoring disimpan di `logs/monitoring.log` pada akar proyek, termasuk ketika script dipanggil dari direktori terminal lain. Pengamatan proses mencatat PID, nama dan status proses, `%CPU`, `%MEM`, serta RSS dalam KiB. PID tidak valid ditolak tanpa membuat nilai metrik palsu.

Jalankan pengujian otomatis anggota 6 dengan:

```bash
bash tests/test-monitoring-rafif.sh
```

## Ketentuan pengembangan

1. Setiap anggota mengerjakan modul yang menjadi tanggung jawabnya pada branch Git masing-masing.
2. Perubahan dikirim melalui commit dan pull request ke repository utama.
3. Fungsi bersama boleh ditempatkan pada `common.sh` setelah disepakati anggota yang terkait.
4. Jangan menyalin password, token, atau data sensitif ke dalam script maupun repository.
5. Script harus menangani kegagalan dengan pesan yang jelas dan exit status yang sesuai.
