#!/usr/bin/env bash
# Regression test untuk validasi path sumber/tujuan pada backup.sh.
# Seluruh pengujian berjalan pada salinan sementara dan tidak mengubah data proyek.

set -Eeuo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test-backup-path-safety.XXXXXX")"
TEST_PROJECT="$TEMP_ROOT/project"
BACKUP_SCRIPT="$TEST_PROJECT/scripts/backup.sh"
VERIFY_SCRIPT="$TEST_PROJECT/scripts/verify.sh"
OUTPUT_DIR="$TEST_PROJECT/output"

cleanup() {
    rm -rf -- "$TEMP_ROOT"
}
trap cleanup EXIT

pass() { printf '[LULUS] %s\n' "$1"; }
fail() { printf '[GAGAL] %s\n' "$1" >&2; exit 1; }

expect_status() {
    local expected="$1"
    local actual="$2"
    local description="$3"
    [[ "$actual" -eq "$expected" ]] || fail "$description (exit status aktual: $actual, diharapkan: $expected)."
}

mkdir -p -- "$TEST_PROJECT" "$TEMP_ROOT/data-sumber" "$TEMP_ROOT/tujuan-backup"
cp -a -- "$PROJECT_ROOT/scripts" "$TEST_PROJECT/"
printf 'Data uji backup path safety.\n' > "$TEMP_ROOT/data-sumber/data.txt"

SOURCE="$TEMP_ROOT/data-sumber"
DEST="$TEMP_ROOT/tujuan-backup"

# Parameter kosong tidak boleh dinormalisasi menjadi '/'.
set +e
bash "$BACKUP_SCRIPT" "" "$DEST" > "$TEMP_ROOT/empty-source.out" 2>&1
EMPTY_SOURCE_STATUS=$?
bash "$BACKUP_SCRIPT" "$SOURCE" "" > "$TEMP_ROOT/empty-dest.out" 2>&1
EMPTY_DEST_STATUS=$?
set -e
expect_status 2 "$EMPTY_SOURCE_STATUS" 'Parameter sumber kosong harus ditolak dengan exit 2'
expect_status 2 "$EMPTY_DEST_STATUS" 'Parameter tujuan kosong harus ditolak dengan exit 2'
grep -Fq 'Parameter sumber dan tujuan tidak boleh kosong' "$TEMP_ROOT/empty-source.out" || fail 'Pesan parameter sumber kosong tidak ditemukan.'
grep -Fq 'Parameter sumber dan tujuan tidak boleh kosong' "$TEMP_ROOT/empty-dest.out" || fail 'Pesan parameter tujuan kosong tidak ditemukan.'
pass 'Parameter sumber/tujuan kosong ditolak sebelum normalisasi path.'

# T04: backup normal dengan trailing slash tetap berfungsi.
if ! bash "$BACKUP_SCRIPT" "$SOURCE/" "$DEST/" > "$TEMP_ROOT/normal-backup.out" 2>&1; then
    cat "$TEMP_ROOT/normal-backup.out" >&2
    fail 'Backup normal dengan trailing slash gagal.'
fi
ARCHIVE="$(find "$DEST" -maxdepth 1 -type f -name 'backup_*.tar.gz' -print -quit)"
[[ -n "$ARCHIVE" && -s "$ARCHIVE" ]] || fail 'Arsip normal tidak terbentuk.'
tar -tzf "$ARCHIVE" | grep -Fq 'data-sumber/data.txt' || fail 'Isi sumber tidak ditemukan di dalam arsip.'
bash "$VERIFY_SCRIPT" verify "$ARCHIVE" >/dev/null || fail 'Checksum arsip normal tidak lolos verifikasi.'
pass 'T04: backup normal tetap berhasil, trailing slash dinormalisasi, dan checksum cocok.'

# Symlink sumber harus diresolusikan sehingga isi direktori target ikut diarsipkan.
ln -s -- "$SOURCE" "$TEMP_ROOT/sumber-link"
mkdir -p -- "$TEMP_ROOT/tujuan-symlink"
if ! bash "$BACKUP_SCRIPT" "$TEMP_ROOT/sumber-link" "$TEMP_ROOT/tujuan-symlink" > "$TEMP_ROOT/symlink-source.out" 2>&1; then
    cat "$TEMP_ROOT/symlink-source.out" >&2
    fail 'Backup melalui symbolic link sumber gagal.'
fi
SYMLINK_ARCHIVE="$(find "$TEMP_ROOT/tujuan-symlink" -maxdepth 1 -type f -name 'backup_*.tar.gz' -print -quit)"
[[ -n "$SYMLINK_ARCHIVE" ]] || fail 'Arsip dari symbolic link sumber tidak ditemukan.'
SYMLINK_LIST="$(tar -tzf "$SYMLINK_ARCHIVE")"
grep -Fq 'data-sumber/data.txt' <<< "$SYMLINK_LIST" || fail 'Arsip symbolic link tidak berisi file target yang sebenarnya.'
if grep -Fq 'sumber-link' <<< "$SYMLINK_LIST"; then
    fail 'Arsip masih menyimpan symbolic link sumber, bukan isi direktori target.'
fi
pass 'Symbolic link sumber diresolusikan dan isi direktori sebenarnya ikut diarsipkan.'

# Tujuan yang sama dengan sumber harus ditolak.
set +e
bash "$BACKUP_SCRIPT" "$SOURCE" "$SOURCE" > "$TEMP_ROOT/same-path.out" 2>&1
SAME_STATUS=$?
set -e
expect_status 7 "$SAME_STATUS" 'Tujuan yang sama dengan sumber harus ditolak dengan exit 7'
grep -Fq 'tujuan sama dengan atau berada di dalam direktori sumber' "$TEMP_ROOT/same-path.out" || fail 'Pesan penolakan tujuan sama dengan sumber tidak ditemukan.'
pass 'Tujuan yang sama dengan sumber ditolak.'

# Tujuan fisik di dalam sumber harus ditolak.
mkdir -p -- "$SOURCE/backup-nested"
set +e
bash "$BACKUP_SCRIPT" "$SOURCE" "$SOURCE/backup-nested" > "$TEMP_ROOT/nested-dest.out" 2>&1
NESTED_STATUS=$?
set -e
expect_status 7 "$NESTED_STATUS" 'Tujuan di dalam sumber harus ditolak dengan exit 7'
grep -Fq 'tujuan sama dengan atau berada di dalam direktori sumber' "$TEMP_ROOT/nested-dest.out" || fail 'Pesan penolakan tujuan di dalam sumber tidak ditemukan.'
pass 'Tujuan yang berada di dalam sumber ditolak.'

# Symlink tujuan yang mengarah ke dalam sumber juga harus ditolak.
ln -s -- "$SOURCE/backup-nested" "$TEMP_ROOT/tujuan-link-ke-dalam-sumber"
set +e
bash "$BACKUP_SCRIPT" "$SOURCE" "$TEMP_ROOT/tujuan-link-ke-dalam-sumber" > "$TEMP_ROOT/symlink-dest.out" 2>&1
SYMLINK_DEST_STATUS=$?
set -e
expect_status 7 "$SYMLINK_DEST_STATUS" 'Symlink tujuan yang mengarah ke dalam sumber harus ditolak dengan exit 7'
pass 'Symbolic link tujuan yang mengarah ke dalam sumber ditolak setelah realpath.'

# Path dengan karakter glob tetap dibandingkan sebagai string literal.
GLOB_SOURCE="$TEMP_ROOT/source[one]"
GLOB_DEST="$GLOB_SOURCE/backup"
mkdir -p -- "$GLOB_SOURCE" "$GLOB_DEST"
set +e
bash "$BACKUP_SCRIPT" "$GLOB_SOURCE" "$GLOB_DEST" > "$TEMP_ROOT/glob-path.out" 2>&1
GLOB_STATUS=$?
set -e
expect_status 7 "$GLOB_STATUS" 'Tujuan di dalam sumber dengan karakter glob harus ditolak'
pass 'Pemeriksaan cakupan path tetap benar untuk nama direktori berisi karakter glob.'

# Root eksplisit tidak boleh dijadikan sumber backup ke direktori mana pun di filesystem.
set +e
bash "$BACKUP_SCRIPT" '/' "$DEST" > "$TEMP_ROOT/root-source.out" 2>&1
ROOT_STATUS=$?
set -e
expect_status 7 "$ROOT_STATUS" 'Sumber root harus ditolak karena semua tujuan berada di dalamnya'
pass 'Sumber root eksplisit ditolak karena tujuan backup pasti berada di dalam sumber.'

# Pastikan tidak ada arsip yang tercipta untuk kasus-kasus yang ditolak.
[[ -z "$(find "$SOURCE/backup-nested" "$GLOB_DEST" -maxdepth 1 -type f -name 'backup_*.tar.gz' -print -quit)" ]] ||
    fail 'Arsip tidak semestinya terbentuk pada tujuan di dalam sumber.'

printf '\nSemua pengujian keamanan path backup lulus pada salinan sementara.\n'
printf 'Catatan: pengujian VM Ubuntu tetap diperlukan sebagai bukti lingkungan kelompok.\n'
