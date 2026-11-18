# Analisis Implementasi Anggota 6 - Monitoring CPU, Memori, dan Proses

## 1. Ruang lingkup

Modul `scripts/monitoring.sh` digunakan untuk mengamati penggunaan sumber daya sistem dan proses yang sedang berjalan selama pengujian backup. Modul ini menyediakan dua jenis pengamatan:

1. Pengamatan kondisi sistem, yaitu penggunaan CPU dan memori secara keseluruhan.
2. Pengamatan proses berdasarkan PID, yaitu nama proses, status proses, penggunaan CPU, persentase memori, dan resident set size (RSS).

Log pemantauan disimpan pada `logs/monitoring.log` di akar proyek. Lokasi ini ditentukan berdasarkan lokasi file script, sehingga tidak berubah ketika script dipanggil dari direktori terminal yang berbeda.

## 2. Pengamatan CPU sistem

Nilai penggunaan CPU sistem dihitung dari perubahan nilai penghitung CPU pada `/proc/stat`. Script mengambil dua sampel dengan jeda satu detik. Selisih total waktu CPU dibandingkan dengan selisih waktu CPU idle untuk memperoleh persentase penggunaan CPU selama interval pengukuran.

Nilai tersebut digunakan untuk menampilkan status `NORMAL`, `PERINGATAN`, atau `TIDAK TERSEDIA`. Ambang peringatan bawaan adalah 80 persen.

## 3. Pengamatan memori sistem

Informasi memori dibaca dari `/proc/meminfo`, khususnya `MemTotal` dan `MemAvailable`. Persentase penggunaan memori dihitung dengan rumus:

```text
Penggunaan memori = (MemTotal - MemAvailable) / MemTotal x 100%
```

Ambang peringatan bawaan adalah 85 persen. Jika informasi tidak tersedia atau nilai total tidak valid, script menampilkan `TIDAK TERSEDIA`, bukan membuat angka pengganti.

## 4. Pengamatan proses berdasarkan PID

Untuk pengamatan proses tertentu, script menggunakan `ps` dengan PID yang diberikan. Informasi yang dicatat meliputi:

- PID proses.
- Nama proses yang dibaca dari `/proc/PID/comm`.
- Status proses.
- Penggunaan CPU dalam persen (`%CPU`).
- Penggunaan memori dalam persen (`%MEM`).
- Resident set size atau RSS dalam KiB.

`%CPU` dari `ps` merupakan rata-rata penggunaan CPU proses selama proses tersebut berjalan, bukan pengukuran instan pada satu inti CPU. `%MEM` menunjukkan proporsi memori fisik yang digunakan proses, sedangkan RSS menunjukkan ukuran memori resident dalam KiB.

Pengamatan satu kali dijalankan menggunakan:

```bash
bash scripts/monitoring.sh --pid PID
```

Pengamatan berulang dengan interval satu detik sampai proses selesai dijalankan menggunakan:

```bash
bash scripts/monitoring.sh --watch-pid PID
```

PID harus berupa bilangan bulat positif. PID yang tidak ditemukan, sudah berhenti, atau tidak dapat diamati akan ditolak dengan pesan yang jelas dan exit status `1`. Format PID yang salah, misalnya teks `abc`, ditolak dengan exit status `2`. Kondisi penolakan dicatat sebagai `STATUS=REJECTED` tanpa mengisi nilai CPU atau memori.

## 5. Pencatatan log

Log disimpan pada `logs/monitoring.log`. Baris pengamatan sistem mencatat waktu, CPU, memori, dan status ambang. Baris pengamatan proses mencatat waktu, PID, nama, status proses, CPU, memori, RSS, dan status pengamatan.

Direktori log dibuat bila belum tersedia. File log diatur dengan izin `600` agar hanya pemilik file yang dapat membacanya atau mengubahnya.

## 6. Hubungan dengan skenario pengujian

| ID | Tujuan | Cara pembuktian |
|---|---|---|
| T15 | Mengamati dan mencatat PID proses backup beserta CPU dan memori | Jalankan backup di latar belakang, catat PID-nya, lalu jalankan `monitoring.sh --watch-pid PID`. Periksa keluaran terminal dan baris `TYPE=PROCESS` di log. |
| T16 | Menangani PID yang tidak valid | Jalankan `monitoring.sh --pid` dengan PID numerik yang tidak ada. Pastikan muncul pesan penolakan dan exit status `1`, tanpa metrik CPU atau memori untuk PID tersebut. |

Pengujian otomatis modul dapat dijalankan dari akar proyek:

```bash
bash tests/test-monitoring-rafif.sh
```

Pengujian otomatis tersebut memeriksa PID aktif, pencatatan metrik, PID yang tidak ditemukan, format PID yang salah, mode pemantauan berulang, dan lokasi log. Hasil pengujian pada salinan sementara tidak menggantikan bukti T15-T16 pada VM Ubuntu kelompok.

## 7. Batasan pengukuran

- Nilai `%CPU` dari `ps` merupakan rata-rata sejak proses berjalan. Untuk proses dengan beban singkat atau rendah, nilai yang tampil dapat berupa `0.0%`.
- Pengukuran PID hanya mencatat proses dengan PID yang diberikan. Proses anak seperti `tar` atau `gzip` perlu diamati menggunakan PID masing-masing bila penggunaan sumber daya proses anak juga ingin ditampilkan.
- Pengamatan proses bergantung pada ketersediaan `/proc` dan utilitas `ps` pada sistem Linux.

## 8. Bukti yang perlu disimpan pada VM Ubuntu kelompok

Simpan tangkapan layar atau keluaran terminal asli untuk:

1. Proses backup sedang berjalan beserta PID yang diamati.
2. Keluaran `--watch-pid` yang menampilkan PID, nama proses, CPU, persentase memori, dan RSS.
3. Baris `TYPE=PROCESS` yang bersesuaian pada `logs/monitoring.log`.
4. Perintah PID tidak valid, pesan penolakan, dan exit status `1`.
5. Baris penolakan PID pada log yang tidak berisi metrik CPU atau memori.
