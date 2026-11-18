# Lembar Pengujian Anggota 5 - T10 sampai T12

## Informasi pengujian

- Penanggung jawab: Izzul
- Lingkungan pengujian: VM Ubuntu Server kelompok
- Script utama: `scripts/backup.sh`
- File lock: `output/backup_5a.lock`
- File log: `output/backup.log`
- File laporan: `output/laporan.txt`

Tanggal pengujian: ____________________
Versi/commit yang diuji: ____________________
Penguji: ____________________

## T10 - Pengujian lock dua proses backup

Tujuan: memastikan proses backup kedua ditolak selama proses backup pertama masih memegang lock.

Prasyarat: direktori sumber dan tujuan valid, `flock` tersedia, dan tidak ada proses backup lain yang sedang berjalan.

Jalankan proses backup pertama pada terminal 1:

```bash
bash scripts/backup.sh /path/ke/sumber /path/ke/tujuan
```

Saat proses pertama masih berlangsung, jalankan perintah backup kedua pada terminal 2 dengan parameter yang sama:

```bash
bash scripts/backup.sh /path/ke/sumber /path/ke/tujuan
STATUS=$?
printf 'Exit status proses kedua: %s\n' "$STATUS"
```

Hasil yang diharapkan: proses kedua menampilkan pesan `Eksekusi ditolak: proses backup lain masih berjalan.` dan menghasilkan exit status bukan nol. Proses pertama tetap melanjutkan backup dan berakhir sesuai hasil prosesnya.

Hasil aktual: ______________________________________________

Exit status proses pertama: __________
Exit status proses kedua: __________

Status: LULUS / GAGAL

Bukti: `evidence/05-lock-log-report/T10-lock-dua-proses.png`

## T11 - Pengujian pencatatan log

Setelah proses backup selesai atau ditolak, periksa log:

```bash
cat output/backup.log
```

Pastikan log memuat baris yang menunjukkan lock berhasil diperoleh, proses kedua ditolak karena lock aktif, serta hasil backup pertama. Setiap baris harus memuat waktu, PID, tingkat pesan, dan keterangan aktivitas.

Hasil aktual: ______________________________________________

Status: LULUS / GAGAL

Bukti: `evidence/05-lock-log-report/T11-log-backup.png`

## T12 - Pengujian laporan backup

Periksa laporan:

```bash
cat output/laporan.txt
```

Ambil path arsip yang tertulis pada kolom `Nama Arsip`, kemudian cocokkan checksum:

```bash
sha256sum "/path/arsip/dari/laporan.tar.gz"
```

Hasil yang diharapkan: laporan memuat nama arsip, waktu eksekusi, checksum SHA-256, hasil verifikasi `LOLOS`, serta status proses dan PID. Nilai checksum harus sama dengan hasil `sha256sum` pada arsip yang tercantum.

Hasil aktual: ______________________________________________

Checksum pada laporan: ____________________________________
Checksum hasil pemeriksaan: ________________________________

Status: LULUS / GAGAL

Bukti: `evidence/05-lock-log-report/T12-laporan-dan-checksum.png`

## Pemeriksaan izin file

Jalankan:

```bash
stat -c '%a %n' output/backup_5a.lock output/backup.log output/laporan.txt
```

Hasil yang diharapkan: setiap file operasional memiliki izin `600`.

Hasil aktual: ______________________________________________

## Catatan

Isi hasil aktual, exit status, tanggal, dan versi commit berdasarkan pelaksanaan pada VM Ubuntu kelompok. Jangan mengisi status LULUS hanya berdasarkan hasil pengujian di komputer atau lingkungan lain.
