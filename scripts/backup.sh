#!/bin/bash
# === ANGGOTA 5: LOCK & LOG ===
OUTPUT_DIR="./output"
LOCK_FILE="/tmp/backup_5a.lock"
LOG_FILE="$OUTPUT_DIR/backup.log"
REPORT_FILE="$OUTPUT_DIR/laporan.txt"

mkdir -p "$OUTPUT_DIR"

catat_log() {
    local level="$1"
    local pesan="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PID:$$] [$level] $pesan" | tee -a "$LOG_FILE"
}

# Buka file descriptor 200 untuk exclusive lock non-blocking
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    catat_log "ERROR" "Eksekusi ditolak: proses backup lain masih berjalan."
    exit 1
fi

catat_log "INFO" "Lock berhasil diperoleh. Memulai rangkaian backup..."
# ====================================

# Script pembuatan arsip backup
# Anggota 2 - Proyek Sistem Operasi 5A

set -Eeuo pipefail

# Berkas baru hanya dapat diakses pemilik (arsip langsung berizin 600)
umask 077

# Memeriksa jumlah parameter
if [ "$#" -ne 2 ]; then
    echo "Penggunaan: $0 <folder_sumber> <folder_tujuan>"
    exit 2
fi

SOURCE="${1%/}"
DEST="${2%/}"

# Menjaga path root '/' agar tidak berubah menjadi string kosong.
[[ -n "$SOURCE" ]] || SOURCE="/"
[[ -n "$DEST" ]] || DEST="/"

# Menentukan lokasi modul berdasarkan lokasi backup.sh.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
VALIDATION_SCRIPT="$SCRIPT_DIR/validation.sh"
VERIFY_SCRIPT="$SCRIPT_DIR/verify.sh"

# Memastikan modul validasi dan verifikasi tersedia.
if [[ ! -f "$VALIDATION_SCRIPT" ]]; then
    catat_log "ERROR" "Modul validation.sh tidak ditemukan: $VALIDATION_SCRIPT"
    exit 1
fi

if [[ ! -f "$VERIFY_SCRIPT" ]]; then
    catat_log "ERROR" "Modul verify.sh tidak ditemukan: $VERIFY_SCRIPT"
    exit 1
fi

# Memvalidasi sumber dan tujuan menggunakan modul Anggota 1.
if bash "$VALIDATION_SCRIPT" "$SOURCE" "$DEST"; then
    :
else
    VALIDATION_STATUS=$?
    catat_log "ERROR" "Backup dihentikan karena validasi gagal (exit status: $VALIDATION_STATUS)."
    exit "$VALIDATION_STATUS"
fi

# Menguji penulisan nyata ke tujuan untuk memastikan direktori benar-benar dapat ditulisi.
# Pemeriksaan ini menjadi lapisan tambahan setelah validasi awal.
TEST_FILE=$(mktemp "$DEST/.write-test.XXXXXX") || {
    catat_log "ERROR" "Folder tujuan tidak dapat ditulis: $DEST"
    exit 1
}
rm -f -- "$TEST_FILE"

# Membuat nama arsip berdasarkan waktu.
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE="$DEST/backup_${TIMESTAMP}_$$.tar.gz"

echo "Memulai proses backup..."
echo "Sumber  : $SOURCE"
echo "Tujuan  : $DEST"

# Membuat arsip.
if tar -czf "$ARCHIVE" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")"; then

    # Membatasi akses arsip hanya untuk pemilik file.
    if ! chmod 600 -- "$ARCHIVE"; then
        echo "ERROR: Gagal mengatur izin akses arsip."
        rm -f -- "$ARCHIVE"
        exit 1
    fi

    # Memeriksa keberadaan dan struktur arsip.
    if [ -s "$ARCHIVE" ] && tar -tzf "$ARCHIVE" > /dev/null; then
        echo "================================"
        echo "ARSIP BERHASIL DIBUAT!"
        echo "Arsip: $ARCHIVE"
        echo "================================"

        # Membuat file checksum melalui modul Anggota 3.
        if bash "$VERIFY_SCRIPT" generate "$ARCHIVE"; then
            :
        else
            VERIFY_STATUS=$?
            catat_log "ERROR" "Pembuatan checksum gagal (exit status: $VERIFY_STATUS)."
            rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
            exit "$VERIFY_STATUS"
        fi

        # Memeriksa checksum yang baru dibuat.
        if bash "$VERIFY_SCRIPT" verify "$ARCHIVE"; then
            :
        else
            VERIFY_STATUS=$?
            catat_log "ERROR" "Verifikasi checksum gagal (exit status: $VERIFY_STATUS)."
            rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
            exit "$VERIFY_STATUS"
        fi

        # === ANGGOTA 5: GENERATOR LAPORAN ===
        WAKTU_SELESAI=$(date '+%Y-%m-%d %H:%M:%S')
        CHECKSUM_ARSIP=$(sha256sum "$ARCHIVE" | awk '{print $1}')

        cat <<EOF_REPORT > "$REPORT_FILE"
==========================================
LAPORAN OTOMASI BACKUP & VERIFIKASI (5A)
==========================================
Nama Arsip       : $ARCHIVE
Waktu Eksekusi   : $WAKTU_SELESAI
Checksum SHA-256 : $CHECKSUM_ARSIP
Hasil Verifikasi : LOLOS (Arsip Valid & Terverifikasi)
Status Proses    : BERHASIL (PID: $$)
==========================================
EOF_REPORT

        catat_log "INFO" "Backup berhasil ($ARCHIVE) dan laporan ditulis ke $REPORT_FILE"
        exit 0
    else
        echo "ERROR: Arsip tidak valid."
        rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
        exit 1
    fi

else
    echo "ERROR: Proses pembuatan arsip gagal."
    rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
    exit 1
fi
