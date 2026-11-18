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

# Memeriksa folder sumber
if [ ! -d "$SOURCE" ]; then
    echo "ERROR: Folder sumber tidak ditemukan: $SOURCE"
    exit 1
fi

# Memeriksa folder tujuan
if [ ! -d "$DEST" ]; then
    echo "ERROR: Folder tujuan tidak ditemukan: $DEST"
    exit 1
fi

# Menguji apakah folder tujuan bisa ditulis
TEST_FILE=$(mktemp "$DEST/.write-test.XXXXXX") || {
    echo "ERROR: Folder tujuan tidak dapat ditulis: $DEST"
    exit 1
}
rm -f -- "$TEST_FILE"

# Membuat nama arsip berdasarkan waktu
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE="$DEST/backup_${TIMESTAMP}_$$.tar.gz"

echo "Memulai proses backup..."
echo "Sumber  : $SOURCE"
echo "Tujuan  : $DEST"

# Membuat arsip
if tar -czf "$ARCHIVE" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")"; then

    # Membatasi akses arsip hanya untuk pemilik file
    if ! chmod 600 -- "$ARCHIVE"; then
        echo "ERROR: Gagal mengatur izin akses arsip."
        rm -f -- "$ARCHIVE"
        exit 1
    fi
    
    # Memeriksa keberadaan dan validitas arsip
    if [ -s "$ARCHIVE" ] && tar -tzf "$ARCHIVE" > /dev/null; then
        echo "================================"
        echo "BACKUP BERHASIL!"
        echo "Arsip: $ARCHIVE"
        echo "================================"

# === ANGGOTA 5: GENERATOR LAPORAN ===
    WAKTU_SELESAI=$(date '+%Y-%m-%d %H:%M:%S')
    CHECKSUM_ARSIP=$(sha256sum "$ARCHIVE" | awk '{print $1}')

    cat <<EOF > "$REPORT_FILE"
==========================================
LAPORAN OTOMASI BACKUP & VERIFIKASI (5A)
==========================================
Nama Arsip       : $ARCHIVE
Waktu Eksekusi   : $WAKTU_SELESAI
Checksum SHA-256 : $CHECKSUM_ARSIP
Hasil Verifikasi : LOLOS (Arsip Valid & Terverifikasi)
Status Proses    : BERHASIL (PID: $$)
==========================================
EOF

    catat_log "INFO" "Backup berhasil ($ARCHIVE) dan laporan ditulis ke $REPORT_FILE"
        exit 0
    else
        echo "ERROR: Arsip tidak valid."
        rm -f -- "$ARCHIVE"
        exit 1
    fi

else
    echo "ERROR: Proses pembuatan arsip gagal."
    rm -f -- "$ARCHIVE"
    exit 1
fi
