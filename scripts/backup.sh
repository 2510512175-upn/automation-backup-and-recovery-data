#!/usr/bin/env bash
# Sistem Otomasi Backup dan Pemulihan Data Linux - Proyek 5A
# Arsip backup: Agung | Lock, log, dan laporan: Izzul

set -Eeuo pipefail
umask 077

# Menentukan direktori proyek berdasarkan lokasi script, bukan working directory.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
OUTPUT_DIR="$PROJECT_ROOT/output"
LOCK_FILE="$OUTPUT_DIR/backup_5a.lock"
LOG_FILE="$OUTPUT_DIR/backup.log"
REPORT_FILE="$OUTPUT_DIR/laporan.txt"

catat_log() {
    local level="$1"
    local pesan="$2"
    local waktu baris

    waktu="$(date '+%Y-%m-%d %H:%M:%S')"
    baris="[$waktu] [PID:$$] [$level] $pesan"

    # Tampilkan ke terminal sekaligus simpan ke log.
    if ! printf '%s\n' "$baris" | tee -a "$LOG_FILE"; then
        printf 'ERROR: Gagal menulis log ke %s\n' "$LOG_FILE" >&2
        return 1
    fi
}

# Siapkan direktori dan amankan berkas operasional sebelum digunakan.
if ! mkdir -p -- "$OUTPUT_DIR"; then
    printf 'ERROR: Tidak dapat membuat direktori output: %s\n' "$OUTPUT_DIR" >&2
    exit 1
fi

if ! touch -- "$LOG_FILE" || ! chmod 600 -- "$LOG_FILE"; then
    printf 'ERROR: Tidak dapat menyiapkan file log: %s\n' "$LOG_FILE" >&2
    exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
    catat_log "ERROR" "Perintah flock tidak tersedia. Instal paket util-linux terlebih dahulu."
    exit 127
fi

# File lock berada di direktori output proyek agar tidak berbagi lock
# dengan salinan proyek lain yang kebetulan memakai nama lock sama di /tmp.
if ! touch -- "$LOCK_FILE" || ! chmod 600 -- "$LOCK_FILE"; then
    catat_log "ERROR" "Tidak dapat menyiapkan file lock: $LOCK_FILE"
    exit 1
fi

# File descriptor 200 memegang exclusive lock sampai proses backup berakhir.
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    catat_log "ERROR" "Eksekusi ditolak: proses backup lain masih berjalan."
    exit 1
fi

catat_log "INFO" "Lock berhasil diperoleh. Memulai rangkaian backup."

# Memeriksa jumlah parameter dan menolak nilai kosong sebelum normalisasi path.
if [[ "$#" -ne 2 ]]; then
    catat_log "ERROR" "Parameter tidak sesuai. Penggunaan: $0 <folder_sumber> <folder_tujuan> (exit status: 2)."
    printf 'Penggunaan: %s <folder_sumber> <folder_tujuan>\n' "$0" >&2
    exit 2
fi

SOURCE_INPUT="$1"
DEST_INPUT="$2"

if [[ -z "$SOURCE_INPUT" || -z "$DEST_INPUT" ]]; then
    catat_log "ERROR" "Parameter sumber dan tujuan tidak boleh kosong (exit status: 2)."
    printf 'ERROR: Parameter sumber dan tujuan tidak boleh kosong.\n' >&2
    exit 2
fi

VALIDATION_SCRIPT="$SCRIPT_DIR/validation.sh"
VERIFY_SCRIPT="$SCRIPT_DIR/verify.sh"

if [[ ! -f "$VALIDATION_SCRIPT" ]]; then
    catat_log "ERROR" "Modul validation.sh tidak ditemukan: $VALIDATION_SCRIPT"
    exit 1
fi

if [[ ! -f "$VERIFY_SCRIPT" ]]; then
    catat_log "ERROR" "Modul verify.sh tidak ditemukan: $VERIFY_SCRIPT"
    exit 1
fi

# Memvalidasi path masukan menggunakan modul Anggota 1 sebelum normalisasi.
if bash "$VALIDATION_SCRIPT" "$SOURCE_INPUT" "$DEST_INPUT"; then
    catat_log "INFO" "Validasi sumber dan tujuan berhasil."
else
    VALIDATION_STATUS=$?
    catat_log "ERROR" "Backup dihentikan karena validasi gagal (exit status: $VALIDATION_STATUS)."
    exit "$VALIDATION_STATUS"
fi

# Resolve symbolic link dan komponen path agar pemeriksaan cakupan memakai
# lokasi fisik yang sebenarnya. realpath juga menghapus trailing slash.
if ! command -v realpath >/dev/null 2>&1; then
    catat_log "ERROR" "Perintah realpath tidak tersedia. Instal paket coreutils terlebih dahulu."
    exit 127
fi

if ! SOURCE="$(realpath -e -- "$SOURCE_INPUT")"; then
    catat_log "ERROR" "Path sumber tidak dapat diresolusikan: $SOURCE_INPUT"
    exit 3
fi

if ! DEST="$(realpath -e -- "$DEST_INPUT")"; then
    catat_log "ERROR" "Path tujuan tidak dapat diresolusikan: $DEST_INPUT"
    exit 5
fi

# Cek ulang tipe direktori setelah path diresolusikan untuk mengurangi risiko
# perubahan path di antara validasi awal dan pembuatan arsip.
if [[ ! -d "$SOURCE" ]]; then
    catat_log "ERROR" "Sumber bukan direktori setelah path diresolusikan: $SOURCE"
    exit 3
fi

if [[ ! -d "$DEST" ]]; then
    catat_log "ERROR" "Tujuan bukan direktori setelah path diresolusikan: $DEST"
    exit 5
fi

# Tujuan tidak boleh sama dengan atau berada di dalam sumber. Pemeriksaan
# dilakukan setelah realpath agar symbolic link dan trailing slash tidak
# dapat melewati validasi cakupan direktori.
SOURCE_PREFIX="${SOURCE%/}/"
if [[ "$DEST" == "$SOURCE" || "${DEST:0:${#SOURCE_PREFIX}}" == "$SOURCE_PREFIX" ]]; then
    catat_log "ERROR" "Konfigurasi path ditolak: direktori tujuan sama dengan atau berada di dalam direktori sumber."
    printf 'ERROR: Direktori tujuan tidak boleh sama dengan atau berada di dalam direktori sumber.\n' >&2
    exit 7
fi

catat_log "INFO" "Path sumber dan tujuan berhasil diresolusikan. Sumber: $SOURCE | Tujuan: $DEST"

# Uji penulisan nyata sebagai lapisan tambahan setelah validasi awal.
if ! TEST_FILE="$(mktemp "$DEST/.write-test.XXXXXX")"; then
    catat_log "ERROR" "Folder tujuan tidak dapat ditulis: $DEST"
    exit 1
fi
rm -f -- "$TEST_FILE"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
ARCHIVE="$DEST/backup_${TIMESTAMP}_$$.tar.gz"

catat_log "INFO" "Proses pembuatan arsip dimulai. Sumber: $SOURCE | Tujuan: $DEST"
printf 'Memulai proses backup...\nSumber  : %s\nTujuan  : %s\n' "$SOURCE" "$DEST"

# Membuat arsip.
if ! tar -czf "$ARCHIVE" -C "$(dirname -- "$SOURCE")" "$(basename -- "$SOURCE")"; then
    catat_log "ERROR" "Proses pembuatan arsip gagal: $ARCHIVE"
    rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
    exit 1
fi

# Membatasi akses arsip hanya untuk pemilik.
if ! chmod 600 -- "$ARCHIVE"; then
    catat_log "ERROR" "Gagal mengatur izin akses arsip: $ARCHIVE"
    rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
    exit 1
fi

# Memeriksa keberadaan dan struktur arsip.
if [[ ! -s "$ARCHIVE" ]] || ! tar -tzf "$ARCHIVE" >/dev/null; then
    catat_log "ERROR" "Arsip tidak valid atau kosong: $ARCHIVE"
    rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
    exit 1
fi

# Membuat checksum melalui modul Anggota 3.
if bash "$VERIFY_SCRIPT" generate "$ARCHIVE"; then
    catat_log "INFO" "Checksum SHA-256 berhasil dibuat untuk $ARCHIVE"
else
    VERIFY_STATUS=$?
    catat_log "ERROR" "Pembuatan checksum gagal (exit status: $VERIFY_STATUS)."
    rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
    exit "$VERIFY_STATUS"
fi

# Memverifikasi checksum yang baru dibuat.
if bash "$VERIFY_SCRIPT" verify "$ARCHIVE"; then
    catat_log "INFO" "Verifikasi checksum berhasil untuk $ARCHIVE"
else
    VERIFY_STATUS=$?
    catat_log "ERROR" "Verifikasi checksum gagal (exit status: $VERIFY_STATUS)."
    rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"
    exit "$VERIFY_STATUS"
fi

# Laporan dibuat melalui file sementara lalu dipindahkan secara atomik.
WAKTU_SELESAI="$(date '+%Y-%m-%d %H:%M:%S')"
CHECKSUM_ARSIP="$(sha256sum -- "$ARCHIVE" | awk '{print $1}')"
REPORT_TMP="$(mktemp "$OUTPUT_DIR/.laporan.XXXXXX")" || {
    catat_log "ERROR" "Gagal membuat file sementara untuk laporan."
    exit 1
}

if ! cat > "$REPORT_TMP" <<EOF_REPORT
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
then
    rm -f -- "$REPORT_TMP"
    catat_log "ERROR" "Gagal menulis isi laporan backup."
    exit 1
fi

if ! chmod 600 -- "$REPORT_TMP" || ! mv -f -- "$REPORT_TMP" "$REPORT_FILE"; then
    rm -f -- "$REPORT_TMP"
    catat_log "ERROR" "Gagal menyimpan laporan backup ke $REPORT_FILE"
    exit 1
fi

catat_log "INFO" "Backup berhasil. Arsip: $ARCHIVE | Laporan: $REPORT_FILE"
printf '================================\nARSIP BERHASIL DIBUAT!\nArsip: %s\nLaporan: %s\n================================\n' "$ARCHIVE" "$REPORT_FILE"
exit 0
