#!/usr/bin/env bash
# Uji otomatis T10-T12 untuk lock, log, dan laporan.
# Pengujian berjalan pada salinan sementara agar tidak mengubah output proyek.

set -Eeuo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d)"
FIRST_PID=""

bersihkan() {
    if [[ -n "$FIRST_PID" ]] && kill -0 "$FIRST_PID" 2>/dev/null; then
        kill "$FIRST_PID" 2>/dev/null || true
        wait "$FIRST_PID" 2>/dev/null || true
    fi
    rm -rf -- "$TEMP_ROOT"
}
trap bersihkan EXIT

lulus() { printf '[LULUS] %s\n' "$1"; }
gagal() { printf '[GAGAL] %s\n' "$1" >&2; exit 1; }

TEST_PROJECT="$TEMP_ROOT/project"
FAKE_BIN="$TEMP_ROOT/fake-bin"
SOURCE="$TEMP_ROOT/data-sumber"
DEST="$TEMP_ROOT/tujuan-backup"
START_MARKER="$TEMP_ROOT/tar-dimulai"
mkdir -p -- "$TEST_PROJECT" "$FAKE_BIN" "$SOURCE" "$DEST" \
    "$TEMP_ROOT/launch-one" "$TEMP_ROOT/launch-two"
cp -a -- "$PROJECT_ROOT/scripts" "$TEST_PROJECT/"

printf 'Data dummy untuk pengujian lock, log, dan laporan.\n' > "$SOURCE/data.txt"

REAL_TAR="$(command -v tar)"
cat > "$FAKE_BIN/tar" <<'EOF_TAR'
#!/usr/bin/env bash
if [[ "${1:-}" == "-czf" ]]; then
    : > "$TAR_STARTED_FILE"
    sleep 3
fi
exec "$REAL_TAR" "$@"
EOF_TAR
chmod +x "$FAKE_BIN/tar"

BACKUP_SCRIPT="$TEST_PROJECT/scripts/backup.sh"
LOG_FILE="$TEST_PROJECT/output/backup.log"
REPORT_FILE="$TEST_PROJECT/output/laporan.txt"
LOCK_FILE="$TEST_PROJECT/output/backup_5a.lock"

# Jalankan backup pertama. Pembungkus tar menahan proses selama tiga detik
# agar proses kedua pasti mencoba masuk ketika lock masih dipegang.
(
    cd "$TEMP_ROOT/launch-one"
    PATH="$FAKE_BIN:$PATH" \
    TAR_STARTED_FILE="$START_MARKER" \
    REAL_TAR="$REAL_TAR" \
    bash "$BACKUP_SCRIPT" "$SOURCE" "$DEST"
) > "$TEMP_ROOT/proses-pertama.log" 2>&1 &
FIRST_PID=$!

for _ in $(seq 1 50); do
    [[ -f "$START_MARKER" ]] && break
    if ! kill -0 "$FIRST_PID" 2>/dev/null; then
        cat "$TEMP_ROOT/proses-pertama.log" >&2 || true
        gagal "Backup pertama berhenti sebelum memasuki proses pembuatan arsip."
    fi
    sleep 0.1
done
[[ -f "$START_MARKER" ]] || gagal "Penanda proses tar pertama tidak ditemukan."

set +e
(
    cd "$TEMP_ROOT/launch-two"
    PATH="$FAKE_BIN:$PATH" \
    TAR_STARTED_FILE="$START_MARKER" \
    REAL_TAR="$REAL_TAR" \
    bash "$BACKUP_SCRIPT" "$SOURCE" "$DEST"
) > "$TEMP_ROOT/proses-kedua.log" 2>&1
SECOND_STATUS=$?
set -e

set +e
wait "$FIRST_PID"
FIRST_STATUS=$?
set -e
FIRST_PID=""

[[ "$FIRST_STATUS" -eq 0 ]] || { cat "$TEMP_ROOT/proses-pertama.log" >&2; gagal "Backup pertama seharusnya berhasil, exit status=$FIRST_STATUS."; }
[[ "$SECOND_STATUS" -ne 0 ]] || gagal "Backup kedua seharusnya ditolak oleh lock, tetapi exit status=0."

grep -Fq '[ERROR] Eksekusi ditolak: proses backup lain masih berjalan.' "$TEMP_ROOT/proses-kedua.log" || gagal "Pesan penolakan lock tidak ditemukan pada keluaran proses kedua."
lulus "T10 - proses backup kedua ditolak saat lock sedang dipegang proses pertama, meskipun dijalankan dari working directory berbeda."

[[ -f "$LOG_FILE" ]] || gagal "File backup.log tidak ditemukan."
grep -Fq '[INFO] Lock berhasil diperoleh.' "$LOG_FILE" || gagal "Log tidak mencatat keberhasilan memperoleh lock."
grep -Fq '[ERROR] Eksekusi ditolak: proses backup lain masih berjalan.' "$LOG_FILE" || gagal "Log tidak mencatat penolakan proses kedua."
grep -Fq '[INFO] Backup berhasil.' "$LOG_FILE" || gagal "Log tidak mencatat keberhasilan backup pertama."
lulus "T11 - log mencatat lock diperoleh, proses kedua ditolak, dan backup berhasil."

# Pastikan kegagalan validasi juga dicatat dan exit status asli tidak hilang.
set +e
bash "$BACKUP_SCRIPT" "$TEMP_ROOT/sumber-tidak-ada" "$DEST" > "$TEMP_ROOT/validasi-gagal.log" 2>&1
VALIDATION_STATUS=$?
set -e
[[ "$VALIDATION_STATUS" -eq 3 ]] || gagal "Kegagalan validasi seharusnya meneruskan exit status 3, aktual=$VALIDATION_STATUS."
grep -Fq 'validasi gagal (exit status: 3)' "$LOG_FILE" || gagal "Log tidak mencatat kegagalan validasi dengan exit status 3."
lulus "T11 - kegagalan validasi dicatat dan exit status 3 diteruskan."

[[ -f "$REPORT_FILE" ]] || gagal "File laporan.txt tidak ditemukan."
for field in 'Nama Arsip' 'Waktu Eksekusi' 'Checksum SHA-256' 'Hasil Verifikasi' 'Status Proses'; do
    grep -Fq "$field" "$REPORT_FILE" || gagal "Kolom '$field' tidak ditemukan pada laporan."
done
ARCHIVE="$(sed -n 's/^Nama Arsip[[:space:]]*:[[:space:]]*//p' "$REPORT_FILE")"
EXPECTED_HASH="$(sed -n 's/^Checksum SHA-256[[:space:]]*:[[:space:]]*//p' "$REPORT_FILE")"
[[ -f "$ARCHIVE" ]] || gagal "Arsip yang tercantum di laporan tidak ditemukan: $ARCHIVE"
ACTUAL_HASH="$(sha256sum -- "$ARCHIVE" | awk '{print $1}')"
[[ "$EXPECTED_HASH" == "$ACTUAL_HASH" ]] || gagal "Checksum dalam laporan tidak sama dengan checksum arsip."
grep -Fq 'Hasil Verifikasi : LOLOS' "$REPORT_FILE" || gagal "Laporan tidak menyatakan verifikasi lolos."
lulus "T12 - laporan memuat informasi wajib dan checksum cocok dengan arsip."

for file in "$LOG_FILE" "$REPORT_FILE" "$LOCK_FILE"; do
    [[ -f "$file" ]] || gagal "Berkas operasional tidak ditemukan: $file"
    MODE="$(stat -c '%a' "$file")"
    [[ "$MODE" == "600" ]] || gagal "Izin $file adalah $MODE, seharusnya 600."
done
lulus "Izin file log, laporan, dan lock adalah 600."

printf '\nSemua pengujian Izzul (T10-T12) lulus pada salinan sementara.\n'
printf 'Catatan: ulangi pengujian pada VM Ubuntu kelompok dan simpan screenshot sebagai bukti proyek.\n'
