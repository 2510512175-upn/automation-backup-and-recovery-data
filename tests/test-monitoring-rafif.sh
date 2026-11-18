#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/monitoring.sh"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test-monitoring-rafif.XXXXXX")"
TEST_PROJECT="$TEMP_ROOT/project"
TEST_SCRIPT="$TEST_PROJECT/scripts/monitoring.sh"
LOG_FILE="$TEST_PROJECT/logs/monitoring.log"
SLEEP_PID=""

cleanup() {
    if [[ -n "$SLEEP_PID" ]] && kill -0 "$SLEEP_PID" 2>/dev/null; then
        kill "$SLEEP_PID" 2>/dev/null || true
        wait "$SLEEP_PID" 2>/dev/null || true
    fi
    rm -rf -- "$TEMP_ROOT"
}
trap cleanup EXIT

pass() {
    printf '[LULUS] %s\n' "$1"
}

fail() {
    printf '[GAGAL] %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local file="$1"
    local expected="$2"
    local description="$3"

    grep -Fq -- "$expected" "$file" || fail "$description"
}

mkdir -p -- "$TEST_PROJECT/scripts"
cp -- "$SOURCE_SCRIPT" "$TEST_SCRIPT"
chmod +x "$TEST_SCRIPT"

bash -n "$SOURCE_SCRIPT" || fail 'Sintaks monitoring.sh tidak valid.'
pass 'Sintaks monitoring.sh valid.'

# Jalankan dari luar direktori proyek untuk menguji lokasi log berdasarkan lokasi script.
sleep 20 &
SLEEP_PID=$!
if ! (cd /tmp && bash "$TEST_SCRIPT" --pid "$SLEEP_PID") > "$TEMP_ROOT/pid-valid.out" 2>&1; then
    cat "$TEMP_ROOT/pid-valid.out" >&2
    fail 'Monitoring PID aktif gagal dijalankan.'
fi

assert_contains "$TEMP_ROOT/pid-valid.out" "PID            : $SLEEP_PID" 'PID aktif tidak ditampilkan.'
assert_contains "$TEMP_ROOT/pid-valid.out" 'Penggunaan CPU :' 'Penggunaan CPU tidak ditampilkan.'
assert_contains "$TEMP_ROOT/pid-valid.out" 'Penggunaan Memori:' 'Penggunaan memori tidak ditampilkan.'
assert_contains "$TEMP_ROOT/pid-valid.out" 'Memori RSS     :' 'Nilai RSS tidak ditampilkan.'
[[ -f "$LOG_FILE" ]] || fail 'Log tidak dibuat pada akar proyek.'
[[ ! -e "$TEST_PROJECT/scripts/logs/monitoring.log" ]] || fail 'Log masih dibuat relatif ke direktori scripts.'
assert_contains "$LOG_FILE" "PID=$SLEEP_PID" 'PID aktif tidak dicatat ke log.'
assert_contains "$LOG_FILE" 'CPU=' 'Metrik CPU tidak dicatat ke log.'
assert_contains "$LOG_FILE" 'MEMORY=' 'Metrik memori tidak dicatat ke log.'
assert_contains "$LOG_FILE" 'RSS_KB=' 'Metrik RSS tidak dicatat ke log.'
pass 'T15: PID aktif, CPU, persentase memori, dan RSS tampil serta tercatat di log.'
pass 'Lokasi log tetap berada di logs/ akar proyek meskipun script dipanggil dari /tmp.'
kill "$SLEEP_PID" 2>/dev/null || true
wait "$SLEEP_PID" 2>/dev/null || true
SLEEP_PID=""

# PID numerik yang tidak sedang digunakan untuk menguji kondisi proses tidak ditemukan.
INVALID_PID=99999999
while [[ -e "/proc/$INVALID_PID" ]]; do
    INVALID_PID=$((INVALID_PID + 1))
done

set +e
bash "$TEST_SCRIPT" --pid "$INVALID_PID" > "$TEMP_ROOT/pid-invalid.out" 2>&1
INVALID_STATUS=$?
set -e

[[ "$INVALID_STATUS" -eq 1 ]] || fail "PID yang tidak ditemukan seharusnya exit 1, aktual: $INVALID_STATUS."
assert_contains "$TEMP_ROOT/pid-invalid.out" "PID $INVALID_PID tidak ditemukan" 'Pesan PID tidak ditemukan tidak jelas.'
assert_contains "$LOG_FILE" "PID=$INVALID_PID,STATUS=REJECTED" 'Penolakan PID tidak tercatat.'
if grep -F "PID=$INVALID_PID" "$LOG_FILE" | grep -Eq 'CPU=|MEMORY=|RSS_KB='; then
    fail 'PID tidak valid menghasilkan metrik CPU atau memori palsu.'
fi
pass 'T16: PID yang tidak ditemukan ditolak dengan pesan jelas dan exit status 1 tanpa metrik palsu.'

set +e
bash "$TEST_SCRIPT" --pid 'abc' > "$TEMP_ROOT/pid-format-invalid.out" 2>&1
FORMAT_STATUS=$?
set -e
[[ "$FORMAT_STATUS" -eq 2 ]] || fail "Format PID yang salah seharusnya exit 2, aktual: $FORMAT_STATUS."
assert_contains "$TEMP_ROOT/pid-format-invalid.out" 'PID tidak valid' 'Pesan format PID tidak valid tidak jelas.'
pass 'Format PID non-numerik ditolak dengan exit status 2.'

# Uji mode pemantauan berulang dan penghentian normal saat proses selesai.
sleep 3 &
SLEEP_PID=$!
if ! bash "$TEST_SCRIPT" --watch-pid "$SLEEP_PID" > "$TEMP_ROOT/watch-pid.out" 2>&1; then
    cat "$TEMP_ROOT/watch-pid.out" >&2
    fail 'Mode --watch-pid gagal.'
fi
assert_contains "$TEMP_ROOT/watch-pid.out" 'Pemantauan selesai' 'Mode --watch-pid tidak berhenti dengan pesan penyelesaian.'
WATCH_SAMPLES="$(grep -Fc "PID=$SLEEP_PID" "$LOG_FILE" || true)"
[[ "$WATCH_SAMPLES" -ge 2 ]] || fail "Mode --watch-pid hanya mencatat $WATCH_SAMPLES sampel, minimal 2."
pass 'Mode --watch-pid mencatat beberapa sampel dan berhenti saat proses selesai.'
SLEEP_PID=""

# Mode pemantauan sistem lama tetap berjalan dan mencatat metrik sistem.
if ! bash "$TEST_SCRIPT" > "$TEMP_ROOT/system.out" 2>&1; then
    cat "$TEMP_ROOT/system.out" >&2
    fail 'Mode pemantauan sistem tanpa argumen gagal.'
fi
assert_contains "$LOG_FILE" 'TYPE=SYSTEM' 'Mode sistem tidak mencatat data sistem.'
pass 'Mode pemantauan sistem yang sudah ada tetap berfungsi.'

printf '\nSemua pengujian monitoring Rafif lulus pada salinan sementara.\n'
printf 'Catatan: T15 harus tetap dibuktikan ulang dengan proses backup aktif pada VM Ubuntu kelompok.\n'
