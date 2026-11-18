# Pengujian Anggota 6 - Monitoring CPU, Memori, dan Proses

## 1. Prasyarat

- Sistem Linux dengan Bash, `ps`, `awk`, dan direktori `/proc`.
- Script dijalankan dari salinan proyek yang sedang diuji.
- Pengujian T15 menggunakan direktori data dummy dan tujuan sementara.
- Pengujian T16 menggunakan PID numerik yang dipastikan tidak ada.

## 2. T15 - Monitoring ketika proses backup berjalan

### Tujuan

Memastikan PID proses backup, penggunaan CPU, dan penggunaan memori dapat diamati serta dicatat ke file log.

### Langkah pengujian

1. Buat direktori sumber dan tujuan sementara.
2. Siapkan data dummy yang cukup besar agar proses backup tidak selesai sebelum pengamatan dilakukan.
3. Jalankan backup di latar belakang dan simpan PID prosesnya.
4. Jalankan monitoring berulang pada PID tersebut.
5. Tunggu proses backup selesai.
6. Periksa baris log untuk PID yang sama.

Contoh perintah dari akar proyek:

```bash
TEST_DIR="$(mktemp -d)"
mkdir -p "$TEST_DIR/sumber" "$TEST_DIR/tujuan"
dd if=/dev/urandom of="$TEST_DIR/sumber/data-dummy.bin" bs=1M count=64 status=progress

bash scripts/backup.sh "$TEST_DIR/sumber" "$TEST_DIR/tujuan" &
BACKUP_PID=$!
printf 'PID backup: %s\n' "$BACKUP_PID"

bash scripts/monitoring.sh --watch-pid "$BACKUP_PID"
wait "$BACKUP_PID"
```

Periksa pencatatan PID:

```bash
grep -F "PID=$BACKUP_PID" logs/monitoring.log
```

### Hasil yang diharapkan

- Script menampilkan PID proses yang diminta.
- Informasi CPU, persentase memori, dan RSS tampil pada terminal.
- Satu atau lebih baris `TYPE=PROCESS` untuk PID tersebut tersimpan di `logs/monitoring.log`.
- Monitoring berhenti dengan pesan penyelesaian ketika proses selesai.

### Bukti yang disimpan

- Screenshot perintah backup di latar belakang dan PID yang diperoleh.
- Screenshot keluaran `--watch-pid`.
- Screenshot baris log dengan PID, CPU, MEMORY, dan RSS_KB.

### Catatan pengukuran

`%CPU` dari `ps` adalah rata-rata selama proses berjalan, sehingga nilai kecil atau `0.0%` dapat muncul pada proses yang singkat atau tidak banyak menggunakan CPU. Jika ingin melihat proses anak yang melakukan kompresi, seperti `tar` atau `gzip`, ambil PID proses anak tersebut dan jalankan mode `--watch-pid` pada PID itu.

## 3. T16 - Monitoring menggunakan PID yang tidak valid

### Tujuan

Memastikan PID yang tidak ditemukan ditangani dengan pesan yang jelas dan tidak menghasilkan metrik CPU atau memori palsu.

### Langkah pengujian

Tentukan PID numerik yang tidak digunakan:

```bash
INVALID_PID=99999999
while [[ -e "/proc/$INVALID_PID" ]]; do
    INVALID_PID=$((INVALID_PID + 1))
done
```

Jalankan monitoring dan periksa exit status:

```bash
bash scripts/monitoring.sh --pid "$INVALID_PID"
printf 'Exit status: %s\n' "$?"
```

### Hasil yang diharapkan

- Muncul pesan bahwa PID tidak ditemukan, sudah berhenti, atau tidak dapat diamati.
- Exit status bernilai `1`.
- Log dapat mencatat penolakan dengan `STATUS=REJECTED`.
- Baris penolakan tidak berisi nilai `CPU`, `MEMORY`, atau `RSS_KB`.

Uji format PID yang salah secara terpisah:

```bash
bash scripts/monitoring.sh --pid abc
printf 'Exit status: %s\n' "$?"
```

Hasil yang diharapkan adalah pesan format PID tidak valid dan exit status `2`.

### Bukti yang disimpan

- Screenshot perintah dengan PID yang tidak ditemukan.
- Screenshot pesan penolakan dan exit status `1`.
- Screenshot baris `STATUS=REJECTED` di log.

## 4. Pengujian otomatis lokal

Dari akar proyek, jalankan:

```bash
bash -n scripts/monitoring.sh
bash -n tests/test-monitoring-rafif.sh
bash tests/test-monitoring-rafif.sh
```

Pengujian otomatis memakai salinan sementara agar tidak mengubah log atau output proyek. Hasil lokal harus dibedakan dari bukti pengujian yang diambil langsung dari VM Ubuntu kelompok.

## 5. Tabel hasil aktual

Isi tabel ini berdasarkan pengujian yang benar-benar dilakukan pada VM Ubuntu kelompok.

| ID | Hasil aktual | Exit status | Bukti | Status |
|---|---|---:|---|---|
| T15 | Isi setelah pengujian VM | Isi setelah pengujian | Nama screenshot/log | Belum diuji di VM |
| T16 | Isi setelah pengujian VM | Isi setelah pengujian | Nama screenshot/log | Belum diuji di VM |
