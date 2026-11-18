#!/usr/bin/env bash
# Regression test integrasi validasi, backup, checksum, dan restore (T01-T09).
# Seluruh data dan output dibuat di direktori sementara.

set -Eeuo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test-core-integration.XXXXXX")"
TEST_PROJECT="$TEMP_ROOT/project"
SCRIPTS_DIR="$TEST_PROJECT/scripts"
BACKUP_SCRIPT="$SCRIPTS_DIR/backup.sh"
VALIDATION_SCRIPT="$SCRIPTS_DIR/validation.sh"
VERIFY_SCRIPT="$SCRIPTS_DIR/verify.sh"
RESTORE_SCRIPT="$SCRIPTS_DIR/restore.sh"
SOURCE="$TEMP_ROOT/data-sumber"
DEST="$TEMP_ROOT/tujuan-backup"
RESTORE_DEST="$TEMP_ROOT/hasil-restore"
CORRUPT_DEST="$TEMP_ROOT/hasil-restore-rusak"

cleanup() { rm -rf -- "$TEMP_ROOT"; }
trap cleanup EXIT
pass() { printf '[LULUS] %s\n' "$1"; }
fail() { printf '[GAGAL] %s\n' "$1" >&2; exit 1; }
expect_status() {
    local expected="$1" actual="$2" description="$3"
    [[ "$actual" -eq "$expected" ]] || fail "$description (exit aktual $actual, diharapkan $expected)."
}

mkdir -p -- "$TEST_PROJECT" "$SOURCE/subdirektori" "$DEST" "$RESTORE_DEST" "$CORRUPT_DEST"
cp -a -- "$PROJECT_ROOT/scripts" "$TEST_PROJECT/"
printf 'Baris pertama\nBaris kedua\n' > "$SOURCE/data.txt"
printf 'Data di dalam subdirektori\n' > "$SOURCE/subdirektori/nested.txt"

# T01-T03: modul validasi.
bash "$VALIDATION_SCRIPT" "$SOURCE" "$DEST" > "$TEMP_ROOT/valid.out" 2>&1 || fail 'T01 sumber dan tujuan valid seharusnya diterima.'
pass 'T01: sumber valid dan dapat dibaca diterima.'

set +e
bash "$VALIDATION_SCRIPT" "$TEMP_ROOT/sumber-tidak-ada" "$DEST" > "$TEMP_ROOT/missing-source.out" 2>&1
MISSING_SOURCE_STATUS=$?
bash "$VALIDATION_SCRIPT" "" "$DEST" > "$TEMP_ROOT/empty-param.out" 2>&1
EMPTY_PARAM_STATUS=$?
printf 'bukan direktori\n' > "$TEMP_ROOT/file-sumber.txt"
bash "$VALIDATION_SCRIPT" "$TEMP_ROOT/file-sumber.txt" "$DEST" > "$TEMP_ROOT/not-dir.out" 2>&1
NOT_DIR_STATUS=$?
bash "$VALIDATION_SCRIPT" "$SOURCE" "$TEMP_ROOT/tujuan-tidak-ada" > "$TEMP_ROOT/missing-dest.out" 2>&1
MISSING_DEST_STATUS=$?
set -e
expect_status 3 "$MISSING_SOURCE_STATUS" 'T02 sumber tidak ditemukan harus exit 3'
expect_status 2 "$EMPTY_PARAM_STATUS" 'T03 parameter wajib kosong harus exit 2'
expect_status 3 "$NOT_DIR_STATUS" 'Sumber berupa file harus ditolak dengan exit 3'
expect_status 5 "$MISSING_DEST_STATUS" 'Tujuan tidak ditemukan harus exit 5'
pass 'T02-T03: sumber tidak tersedia, sumber bukan direktori, parameter kosong, dan tujuan tidak tersedia ditolak.'

# T04: backup menghasilkan arsip, checksum, dan permission yang benar.
if ! bash "$BACKUP_SCRIPT" "$SOURCE" "$DEST" > "$TEMP_ROOT/backup.out" 2>&1; then
    cat "$TEMP_ROOT/backup.out" >&2
    fail 'T04 pembuatan backup gagal.'
fi
ARCHIVE="$(sed -n 's/^Nama Arsip[[:space:]]*:[[:space:]]*//p' "$TEST_PROJECT/output/laporan.txt")"
[[ -n "$ARCHIVE" && -s "$ARCHIVE" ]] || fail 'Arsip dari laporan tidak ditemukan atau kosong.'
[[ "$(stat -c '%a' "$ARCHIVE")" == '600' ]] || fail 'Permission arsip bukan 600.'
tar -tzf "$ARCHIVE" | grep -Fq 'data-sumber/data.txt' || fail 'File sumber tidak ada di dalam arsip.'
bash "$VERIFY_SCRIPT" verify "$ARCHIVE" >/dev/null || fail 'Checksum arsip asli seharusnya cocok.'
pass 'T04: backup berhasil, arsip valid, isi sumber terarsip, checksum cocok, dan permission 600.'

# T17-T18: pemilik arsip dapat membaca, akun lain ditolak oleh permission 600.
ACCESS_DIR="$TEMP_ROOT/access-test"
mkdir -p -- "$ACCESS_DIR"
chmod 755 "$TEMP_ROOT" "$ACCESS_DIR"
ACCESS_ARCHIVE="$ACCESS_DIR/arsip-private.tar.gz"
cp -- "$ARCHIVE" "$ACCESS_ARCHIVE"
chmod 600 "$ACCESS_ARCHIVE"
tar -tzf "$ACCESS_ARCHIVE" >/dev/null || fail 'T17 pemilik tidak dapat membaca arsip miliknya.'
pass 'T17: pemilik arsip dapat membaca arsip berizin 600.'

if [[ "$(id -u)" -eq 0 ]] && command -v runuser >/dev/null 2>&1 && id nobody >/dev/null 2>&1; then
    set +e
    runuser -u nobody -- tar -tzf "$ACCESS_ARCHIVE" > "$TEMP_ROOT/t18.out" 2>&1
    T18_STATUS=$?
    set -e
    [[ "$T18_STATUS" -ne 0 ]] || fail 'T18 akun nobody seharusnya tidak dapat membaca arsip berizin 600.'
    pass 'T18: akun lain ditolak saat mencoba membaca arsip berizin 600.'
else
    printf '[LEWATI] T18: perlu hak root dan runuser/nobody untuk menguji akun lain secara otomatis.\n'
fi

# T06-T07: verifikasi asli lolos, perubahan arsip terdeteksi.
CORRUPT_ARCHIVE="$TEMP_ROOT/backup-rusak.tar.gz"
cp -- "$ARCHIVE" "$CORRUPT_ARCHIVE"
cp -- "${ARCHIVE}.sha256" "${CORRUPT_ARCHIVE}.sha256"
printf 'perubahan uji' >> "$CORRUPT_ARCHIVE"
bash "$VERIFY_SCRIPT" verify "$ARCHIVE" >/dev/null || fail 'T06 arsip asli tidak lolos verifikasi.'
set +e
bash "$VERIFY_SCRIPT" verify "$CORRUPT_ARCHIVE" > "$TEMP_ROOT/verify-corrupt.out" 2>&1
CORRUPT_VERIFY_STATUS=$?
set -e
expect_status 1 "$CORRUPT_VERIFY_STATUS" 'T07 arsip yang diubah harus gagal verifikasi dengan exit 1'
pass 'T06-T07: arsip asli lolos, sedangkan arsip yang diubah terdeteksi tidak cocok.'

# T08: restore arsip valid dan cocokkan seluruh isi.
if ! bash "$RESTORE_SCRIPT" "$ARCHIVE" "$RESTORE_DEST" > "$TEMP_ROOT/restore.out" 2>&1; then
    cat "$TEMP_ROOT/restore.out" >&2
    fail 'T08 restore arsip valid gagal.'
fi
diff -r -- "$SOURCE" "$RESTORE_DEST/$(basename -- "$SOURCE")" >/dev/null || fail 'Isi hasil restore berbeda dari sumber.'
pass 'T08: restore arsip valid berhasil dan isi hasil restore identik dengan sumber.'

# T09: restore menolak arsip yang checksum-nya tidak cocok sebelum ekstraksi.
set +e
bash "$RESTORE_SCRIPT" "$CORRUPT_ARCHIVE" "$CORRUPT_DEST" > "$TEMP_ROOT/restore-corrupt.out" 2>&1
CORRUPT_RESTORE_STATUS=$?
set -e
[[ "$CORRUPT_RESTORE_STATUS" -ne 0 ]] || fail 'T09 restore arsip rusak seharusnya ditolak.'
[[ -z "$(find "$CORRUPT_DEST" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail 'T09 direktori tujuan berisi data setelah restore ditolak.'
grep -Fq 'verifikasi checksum gagal' "$TEMP_ROOT/restore-corrupt.out" || fail 'Pesan penolakan checksum pada restore tidak ditemukan.'
pass 'T09: restore menolak arsip rusak sebelum ekstraksi dan direktori tujuan tetap kosong.'

# T05: jalankan sebagai akun non-root agar permission 555 benar-benar diuji.
T05_PROJECT="$TEMP_ROOT/t05-project"
T05_SOURCE="$TEMP_ROOT/t05-source"
T05_DEST="$TEMP_ROOT/t05-dest"
mkdir -p -- "$T05_PROJECT" "$T05_SOURCE" "$T05_DEST"
cp -a -- "$PROJECT_ROOT/scripts" "$T05_PROJECT/"
printf 'data T05\n' > "$T05_SOURCE/data.txt"
chmod 555 "$T05_DEST"

if [[ "$(id -u)" -eq 0 ]] && command -v runuser >/dev/null 2>&1 && id nobody >/dev/null 2>&1; then
    chmod 755 "$TEMP_ROOT"
    chown -R nobody:nogroup "$T05_PROJECT" "$T05_SOURCE" "$T05_DEST" 2>/dev/null ||
        chown -R nobody:nobody "$T05_PROJECT" "$T05_SOURCE" "$T05_DEST"
    set +e
    runuser -u nobody -- bash "$T05_PROJECT/scripts/backup.sh" "$T05_SOURCE" "$T05_DEST" > "$TEMP_ROOT/t05.out" 2>&1
    T05_STATUS=$?
    set -e
elif [[ "$(id -u)" -ne 0 ]]; then
    set +e
    bash "$T05_PROJECT/scripts/backup.sh" "$T05_SOURCE" "$T05_DEST" > "$TEMP_ROOT/t05.out" 2>&1
    T05_STATUS=$?
    set -e
else
    T05_STATUS=999
fi

if [[ "$T05_STATUS" -eq 999 ]]; then
    printf '[LEWATI] T05: tidak ada runuser/nobody untuk menguji izin direktori sebagai non-root.\n'
else
    expect_status 6 "$T05_STATUS" 'T05 tujuan tidak dapat ditulis harus ditolak oleh validation.sh dengan exit 6'
    grep -Fq 'Direktori tujuan tidak dapat ditulis' "$TEMP_ROOT/t05.out" || fail 'T05 pesan tujuan tidak dapat ditulis tidak ditemukan.'
    [[ -z "$(find "$T05_DEST" -maxdepth 1 -type f -name 'backup_*.tar.gz' -print -quit)" ]] || fail 'T05 arsip terbentuk meskipun tujuan tidak dapat ditulis.'
    pass 'T05: tujuan read-only ditolak sebagai akun non-root dan tidak menghasilkan arsip.'
fi

printf '\nPengujian integrasi T01-T09 dan T17-T18 selesai pada salinan sementara.\n'
printf 'Pengujian VM Ubuntu kelompok tetap diperlukan untuk bukti akhir lingkungan proyek.\n'
