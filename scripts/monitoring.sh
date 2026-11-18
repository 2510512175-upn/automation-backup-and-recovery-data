#!/usr/bin/env bash

# ==========================================
# PEMANTAUAN SISTEM CADANGAN (BACKUP)
# Anggota 6 - Rafif
# Pemantauan CPU, Memori, dan Proses
# ==========================================

set -o pipefail
umask 077

# Lokasi log selalu mengacu pada akar proyek, bukan working directory terminal.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/monitoring.log"

# Batas penggunaan sumber daya sistem.
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85

# Interval pemantauan.
INTERVAL=5
PROCESS_INTERVAL=1

# Menyiapkan direktori dan file log dengan izin pemilik saja.
if ! mkdir -p -- "$LOG_DIR"; then
    printf 'ERROR: Tidak dapat membuat direktori log: %s\n' "$LOG_DIR" >&2
    exit 1
fi

if ! touch -- "$LOG_FILE" || ! chmod 600 -- "$LOG_FILE"; then
    printf 'ERROR: Tidak dapat menyiapkan file log: %s\n' "$LOG_FILE" >&2
    exit 1
fi

write_log() {
    local message="$1"

    if ! printf '%s\n' "$message" >> "$LOG_FILE"; then
        printf 'ERROR: Gagal menulis log ke %s\n' "$LOG_FILE" >&2
        return 1
    fi
}

# ==========================================
# PEMANTAUAN CPU SISTEM
# ==========================================

get_cpu_usage() {
    local total1 idle1 total2 idle2

    if [[ ! -r /proc/stat ]]; then
        printf 'N/A\n'
        return 1
    fi

    read -r total1 idle1 < <(
        awk '/^cpu / {
            total=0
            for (i=2; i<=NF; i++) total+=$i
            print total, $5+$6
        }' /proc/stat
    )

    sleep 1

    read -r total2 idle2 < <(
        awk '/^cpu / {
            total=0
            for (i=2; i<=NF; i++) total+=$i
            print total, $5+$6
        }' /proc/stat
    )

    awk -v t1="$total1" -v t2="$total2" -v i1="$idle1" -v i2="$idle2" '
        BEGIN {
            total_diff = t2 - t1
            idle_diff = i2 - i1
            if (total_diff <= 0) {
                print "0.00"
            } else {
                usage = (total_diff - idle_diff) / total_diff * 100
                printf "%.2f", usage
            }
        }'
}

# ==========================================
# PEMANTAUAN MEMORI SISTEM
# ==========================================

get_memory_usage() {
    awk '
    /^MemTotal:/ { total=$2 }
    /^MemAvailable:/ { available=$2 }
    END {
        if (total > 0) {
            usage=(total-available)/total*100
            printf "%.2f", usage
        } else {
            print "N/A"
            exit 1
        }
    }' /proc/meminfo
}

# ==========================================
# PEMANTAUAN PID PROSES
# ==========================================

is_valid_pid_format() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

# Mengisi variabel PROCESS_* untuk PID yang masih aktif dan dapat diamati.
get_process_stats() {
    local requested_pid="$1"
    local stats

    [[ -d "/proc/$requested_pid" ]] || return 1

    stats="$(ps -p "$requested_pid" -o pid= -o stat= -o %cpu= -o %mem= -o rss= 2>/dev/null)" || return 1
    [[ -n "$stats" ]] || return 1

    read -r PROCESS_PID PROCESS_STATE PROCESS_CPU PROCESS_MEMORY PROCESS_RSS <<< "$stats"
    [[ "$PROCESS_PID" == "$requested_pid" ]] || return 1
    [[ "$PROCESS_STATE" != Z* ]] || return 1

    if [[ -r "/proc/$requested_pid/comm" ]]; then
        PROCESS_COMMAND="$(< "/proc/$requested_pid/comm")"
        PROCESS_COMMAND="${PROCESS_COMMAND//$'\n'/ }"
        PROCESS_COMMAND="${PROCESS_COMMAND% }"
    else
        PROCESS_COMMAND="tidak-diketahui"
    fi
}

record_process_stats() {
    local timestamp
    local log_line

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    log_line="$timestamp,TYPE=PROCESS,PID=$PROCESS_PID,COMMAND=$PROCESS_COMMAND,STATE=$PROCESS_STATE,CPU=${PROCESS_CPU}%,MEMORY=${PROCESS_MEMORY}%,RSS_KB=$PROCESS_RSS,STATUS=ACTIVE"

    if ! write_log "$log_line"; then
        return 1
    fi

    printf '\n==========================================\n'
    printf '       PEMANTAUAN PROSES BACKUP\n'
    printf '==========================================\n'
    printf 'Waktu          : %s\n' "$timestamp"
    printf 'PID            : %s\n' "$PROCESS_PID"
    printf 'Nama proses    : %s\n' "$PROCESS_COMMAND"
    printf 'Status proses  : %s\n' "$PROCESS_STATE"
    printf 'Penggunaan CPU : %s%%\n' "$PROCESS_CPU"
    printf 'Penggunaan Memori: %s%%\n' "$PROCESS_MEMORY"
    printf 'Memori RSS     : %s KB\n' "$PROCESS_RSS"
    printf 'Data dicatat di: %s\n' "$LOG_FILE"
    printf '==========================================\n'
}

monitor_pid() {
    local pid="$1"
    local timestamp

    if ! is_valid_pid_format "$pid"; then
        printf 'ERROR: PID tidak valid. Masukkan PID berupa bilangan bulat positif.\n' >&2
        return 2
    fi

    if ! get_process_stats "$pid"; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        write_log "$timestamp,TYPE=PROCESS,PID=$pid,STATUS=REJECTED,REASON=PID_NOT_ACTIVE_OR_NOT_VISIBLE" || return 1
        printf 'ERROR: Proses dengan PID %s tidak ditemukan, sudah berhenti, atau tidak dapat diamati.\n' "$pid" >&2
        return 1
    fi

    record_process_stats
}

watch_pid() {
    local pid="$1"
    local sample_count=0
    local timestamp

    if ! is_valid_pid_format "$pid"; then
        printf 'ERROR: PID tidak valid. Masukkan PID berupa bilangan bulat positif.\n' >&2
        return 2
    fi

    # Validasi awal agar PID yang sejak awal tidak ada tidak dianggap berhasil.
    if ! get_process_stats "$pid"; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        write_log "$timestamp,TYPE=PROCESS,PID=$pid,STATUS=REJECTED,REASON=PID_NOT_ACTIVE_OR_NOT_VISIBLE" || return 1
        printf 'ERROR: Proses dengan PID %s tidak ditemukan, sudah berhenti, atau tidak dapat diamati.\n' "$pid" >&2
        return 1
    fi

    printf 'Memulai pemantauan PID %s. Interval: %s detik.\n' "$pid" "$PROCESS_INTERVAL"
    printf 'Monitoring berhenti otomatis ketika proses selesai.\n'

    while get_process_stats "$pid"; do
        if ! record_process_stats; then
            return 1
        fi
        sample_count=$((sample_count + 1))
        sleep "$PROCESS_INTERVAL"
    done

    if (( sample_count == 0 )); then
        printf 'ERROR: Proses dengan PID %s berhenti sebelum data berhasil dicatat.\n' "$pid" >&2
        return 1
    fi

    printf 'Proses dengan PID %s sudah berhenti. Pemantauan selesai (%s sampel).\n' "$pid" "$sample_count"
}

# ==========================================
# PEMANTAUAN SISTEM
# ==========================================

monitor_system() {
    local timestamp cpu memory cpu_status memory_status backup_processes log_line

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    cpu="$(get_cpu_usage)" || true
    memory="$(get_memory_usage)" || true

    printf '\n==========================================\n'
    printf '       PEMANTAUAN SISTEM CADANGAN\n'
    printf '==========================================\n'
    printf 'Waktu             : %s\n' "$timestamp"
    printf 'Penggunaan CPU    : %s%%\n' "$cpu"
    printf 'Penggunaan Memori : %s%%\n' "$memory"
    printf '%s\n' '------------------------------------------'

    if [[ "$cpu" == "N/A" ]]; then
        cpu_status="TIDAK TERSEDIA"
        printf 'Status CPU        : TIDAK TERSEDIA\n'
    elif awk -v c="$cpu" -v t="$CPU_THRESHOLD" 'BEGIN {exit !(c >= t)}'; then
        cpu_status="PERINGATAN"
        printf 'Status CPU        : PERINGATAN - Penggunaan CPU tinggi!\n'
    else
        cpu_status="NORMAL"
        printf 'Status CPU        : NORMAL\n'
    fi

    if [[ "$memory" == "N/A" ]]; then
        memory_status="TIDAK TERSEDIA"
        printf 'Status Memori     : TIDAK TERSEDIA\n'
    elif awk -v m="$memory" -v t="$MEMORY_THRESHOLD" 'BEGIN {exit !(m >= t)}'; then
        memory_status="PERINGATAN"
        printf 'Status Memori     : PERINGATAN - Penggunaan memori tinggi!\n'
    else
        memory_status="NORMAL"
        printf 'Status Memori     : NORMAL\n'
    fi

    printf '%s\n' '------------------------------------------'
    printf 'PROSES BACKUP:\n'

    backup_processes="$(ps -eo pid,comm,%cpu,%mem,args | grep -E '[b]ackup\.sh|[r]estore\.sh|[t]ar |[g]zip|[s]ha256sum' || true)"
    if [[ -n "$backup_processes" ]]; then
        printf '%s\n' "$backup_processes"
    else
        printf 'Tidak ditemukan proses backup yang aktif.\n'
    fi

    printf '%s\n' '------------------------------------------'
    printf '5 PROSES DENGAN PENGGUNAAN CPU TERTINGGI:\n'
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6
    printf '==========================================\n'

    log_line="$timestamp,TYPE=SYSTEM,CPU=$cpu%,MEMORY=$memory%,CPU_STATUS=$cpu_status,MEMORY_STATUS=$memory_status"
    write_log "$log_line" || return 1
    printf 'Data pemantauan disimpan di: %s\n' "$LOG_FILE"
}

show_usage() {
    cat <<EOF_USAGE
Penggunaan:
  bash scripts/monitoring.sh
  bash scripts/monitoring.sh --watch
  bash scripts/monitoring.sh --pid PID
  bash scripts/monitoring.sh --watch-pid PID

Keterangan:
  --watch       Memantau kondisi sistem setiap $INTERVAL detik.
  --pid PID     Mengambil satu sampel CPU dan memori dari PID tertentu.
  --watch-pid   Memantau PID setiap $PROCESS_INTERVAL detik sampai proses selesai.
EOF_USAGE
}

# ==========================================
# PROGRAM UTAMA
# ==========================================

case "${1:-}" in
    --watch)
        if [[ "$#" -ne 1 ]]; then
            printf 'ERROR: Opsi --watch tidak menerima parameter tambahan.\n' >&2
            show_usage >&2
            exit 2
        fi
        printf 'Memulai pemantauan sistem secara berkelanjutan...\n'
        printf 'Tekan CTRL+C untuk menghentikan.\n'
        while true; do
            monitor_system || exit 1
            sleep "$INTERVAL"
        done
        ;;
    --pid)
        if [[ "$#" -ne 2 ]]; then
            printf 'ERROR: Opsi --pid membutuhkan satu nilai PID.\n' >&2
            show_usage >&2
            exit 2
        fi
        monitor_pid "$2"
        exit $?
        ;;
    --watch-pid)
        if [[ "$#" -ne 2 ]]; then
            printf 'ERROR: Opsi --watch-pid membutuhkan satu nilai PID.\n' >&2
            show_usage >&2
            exit 2
        fi
        watch_pid "$2"
        exit $?
        ;;
    "")
        if [[ "$#" -ne 0 ]]; then
            printf 'ERROR: Argumen tidak valid.\n' >&2
            show_usage >&2
            exit 2
        fi
        monitor_system
        ;;
    *)
        printf 'ERROR: Argumen tidak valid: %s\n' "$1" >&2
        show_usage >&2
        exit 2
        ;;
esac
