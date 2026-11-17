#!/usr/bin/env bash

# Modul pemulihan data - Anggota 4
# Memverifikasi arsip sebelum mengekstrak ke direktori pengujian.

set -Eeuo pipefail

usage() {
    cat <<USAGE
Penggunaan:
  $0 <file_arsip.tar.gz> <direktori_tujuan>

Ketentuan:
  - File checksum harus tersedia dengan akhiran .sha256.
  - Direktori tujuan harus sudah ada, dapat ditulis, dan kosong.
USAGE
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
    exit 2
fi

ARCHIVE_INPUT=$1
DEST_INPUT=$2

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify.sh"

# Memeriksa utilitas yang dibutuhkan.
for command_name in realpath tar mktemp find mv; do
    command -v "$command_name" >/dev/null 2>&1 ||
        fail "Utilitas '$command_name' tidak ditemukan."
done

[[ -f "$VERIFY_SCRIPT" ]] ||
    fail "Script verify.sh tidak ditemukan."

# 1. Memeriksa keberadaan dan izin baca arsip.
[[ -f "$ARCHIVE_INPUT" ]] ||
    fail "File arsip tidak ditemukan: $ARCHIVE_INPUT"

[[ -r "$ARCHIVE_INPUT" ]] ||
    fail "File arsip tidak dapat dibaca."

ARCHIVE=$(realpath -e -- "$ARCHIVE_INPUT") ||
    fail "Path arsip tidak valid."

# 2. Memeriksa direktori tujuan.
[[ -d "$DEST_INPUT" ]] ||
    fail "Direktori tujuan tidak ditemukan: $DEST_INPUT"

[[ ! -L "$DEST_INPUT" ]] ||
    fail "Direktori tujuan tidak boleh berupa symbolic link."

DEST_DIR=$(cd -- "$DEST_INPUT" && pwd -P) ||
    fail "Direktori tujuan tidak dapat diakses."

[[ -w "$DEST_DIR" && -x "$DEST_DIR" ]] ||
    fail "Direktori tujuan tidak dapat ditulisi atau diakses."

# Memastikan direktori tujuan benar-benar kosong,
# termasuk file tersembunyi.
shopt -s dotglob nullglob
DEST_CONTENTS=("$DEST_DIR"/*)
shopt -u dotglob nullglob

((${#DEST_CONTENTS[@]} == 0)) ||
    fail "Direktori tujuan harus kosong: $DEST_DIR"

# 3. Memverifikasi checksum melalui modul Anggota 3.
echo "[1/4] Memverifikasi checksum arsip..."

if ! bash "$VERIFY_SCRIPT" verify "$ARCHIVE"; then
    fail "Arsip ditolak karena verifikasi checksum gagal."
fi

# Menyiapkan file sementara untuk daftar isi arsip.
LIST_FILE=$(mktemp) ||
    fail "Gagal membuat file sementara."

STAGING_DIR=""

cleanup() {
    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        rm -rf -- "$STAGING_DIR"
    fi

    if [[ -n "${LIST_FILE:-}" && -f "$LIST_FILE" ]]; then
        rm -f -- "$LIST_FILE"
    fi
}

trap cleanup EXIT

# 4. Memeriksa struktur arsip sebelum ekstraksi.
echo "[2/4] Memeriksa struktur arsip..."

if ! tar --absolute-names --quoting-style=escape \
    -tzf "$ARCHIVE" > "$LIST_FILE"; then
    fail "Struktur arsip TAR/GZIP tidak valid atau rusak."
fi

[[ -s "$LIST_FILE" ]] ||
    fail "Arsip tidak memiliki entri untuk dipulihkan."

# Menolak path absolut dan path traversal.
while IFS= read -r MEMBER || [[ -n "$MEMBER" ]]; do

    [[ -n "$MEMBER" ]] || continue

    case "$MEMBER" in
        /*|[A-Za-z]:/*)
            fail "Path absolut tidak diizinkan: $MEMBER"
            ;;
    esac

    NORMALIZED_MEMBER=$MEMBER

    while [[ "$NORMALIZED_MEMBER" == ./* ]]; do
        NORMALIZED_MEMBER=${NORMALIZED_MEMBER#./}
    done

    IFS='/' read -r -a PATH_COMPONENTS <<< "$NORMALIZED_MEMBER"

    for COMPONENT in "${PATH_COMPONENTS[@]}"; do
        [[ "$COMPONENT" != ".." ]] ||
            fail "Path traversal tidak diizinkan: $MEMBER"
    done

done < "$LIST_FILE"

# 5. Ekstraksi dilakukan di direktori sementara.
# Dengan demikian, kegagalan ekstraksi tidak langsung
# mencampurkan hasil parsial dengan direktori tujuan.
echo "[3/4] Mengekstrak arsip ke area sementara..."

STAGING_DIR=$(mktemp -d "$DEST_DIR/.restore-stage.XXXXXX") ||
    fail "Gagal membuat direktori sementara."

if ! tar --extract --gzip \
    --file="$ARCHIVE" \
    --directory="$STAGING_DIR" \
    --no-same-owner \
    --no-same-permissions; then

    fail "Ekstraksi arsip gagal. Pemulihan dibatalkan."
fi

# 6. Memindahkan hasil ekstraksi ke direktori tujuan.
echo "[4/4] Menyelesaikan pemulihan data..."

if ! find "$STAGING_DIR" \
    -mindepth 1 -maxdepth 1 \
    -exec mv -t "$DEST_DIR" -- {} +; then

    fail "Gagal memindahkan hasil pemulihan."
fi

# Membersihkan direktori sementara.
rmdir -- "$STAGING_DIR" ||
    fail "Gagal membersihkan direktori sementara."

STAGING_DIR=""

echo "=========================================="
echo "PEMULIHAN BERHASIL!"
echo "Arsip     : $ARCHIVE"
echo "Direktori : $DEST_DIR"
echo "=========================================="
