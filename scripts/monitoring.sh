#!/bin/bash

# ==========================================
# PEMANTAUAN SISTEM CADANGAN (BACKUP)
# Anggota 6 - Rafif
# Pemantauan CPU, Memori, dan Proses
# ==========================================

# Direktori proyek
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/monitoring.log"

# Batas penggunaan sumber daya
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85

# Interval pemantauan
INTERVAL=5

# Membuat direktori log
mkdir -p "$LOG_DIR" || {
    echo "ERROR: Tidak dapat membuat direktori log."
    exit 1
}

# ==========================================
# PEMANTAUAN CPU
# ==========================================

get_cpu_usage() {

    if [[ ! -r /proc/stat ]]; then
        echo "N/A"
        return 1
    fi

    # Pengukuran CPU pertama
    read -r TOTAL1 IDLE1 < <(
        awk '/^cpu / {
            total=0
            for (i=2; i<=NF; i++) total+=$i
            print total, $5+$6
        }' /proc/stat
    )

    sleep 1

    # Pengukuran CPU kedua
    read -r TOTAL2 IDLE2 < <(
        awk '/^cpu / {
            total=0
            for (i=2; i<=NF; i++) total+=$i
            print total, $5+$6
        }' /proc/stat
    )

    # Menghitung penggunaan CPU
    awk -v t1="$TOTAL1" \
        -v t2="$TOTAL2" \
        -v i1="$IDLE1" \
        -v i2="$IDLE2" '
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
# PEMANTAUAN MEMORI
# ==========================================

get_memory_usage() {

    awk '
    /^MemTotal:/ {
        total=$2
    }

    /^MemAvailable:/ {
        available=$2
    }

    END {
        if (total > 0) {
            usage=(total-available)/total*100
            printf "%.2f", usage
        } else {
            print "0.00"
        }
    }' /proc/meminfo
}

# ==========================================
# PEMANTAUAN SISTEM
# ==========================================

monitor_system() {

    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    CPU=$(get_cpu_usage)
    MEMORY=$(get_memory_usage)

    echo ""
    echo "=========================================="
    echo "       PEMANTAUAN SISTEM CADANGAN"
    echo "=========================================="

    echo "Waktu        : $TIMESTAMP"
    echo "Penggunaan CPU   : $CPU%"
    echo "Penggunaan Memori: $MEMORY%"
    echo "------------------------------------------"

    # Status CPU
    if [[ "$CPU" == "N/A" ]]; then
        CPU_STATUS="TIDAK TERSEDIA"
        echo "Status CPU  : TIDAK TERSEDIA"
    elif awk -v c="$CPU" -v t="$CPU_THRESHOLD" \
        'BEGIN {exit !(c >= t)}'; then
        CPU_STATUS="PERINGATAN"
        echo "Status CPU  : PERINGATAN - Penggunaan CPU tinggi!"
    else
        CPU_STATUS="NORMAL"
        echo "Status CPU  : NORMAL"
    fi

    # Status memori
    if awk -v m="$MEMORY" -v t="$MEMORY_THRESHOLD" \
        'BEGIN {exit !(m >= t)}'; then
        MEMORY_STATUS="PERINGATAN"
        echo "Status Memori: PERINGATAN - Penggunaan memori tinggi!"
    else
        MEMORY_STATUS="NORMAL"
        echo "Status Memori: NORMAL"
    fi

    echo "------------------------------------------"
    echo "PROSES BACKUP:"

    # Kode deteksi proses yang diperbarui
    BACKUP_PROCESSES=$(ps -eo pid,comm,%cpu,%mem,args | grep -E '[b]ackup\.sh|[r]estore\.sh|[t]ar |[g]zip|[s]ha256sum')

    if [[ -n "$BACKUP_PROCESSES" ]]; then
        echo "$BACKUP_PROCESSES"
    else
        echo "Tidak ditemukan proses backup yang aktif."
    fi

    echo "------------------------------------------"
    echo "5 PROSES DENGAN PENGGUNAAN CPU TERTINGGI:"

    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6

    echo "=========================================="

    # Menyimpan hasil pemantauan
    echo "$TIMESTAMP,CPU=$CPU%,MEMORY=$MEMORY%,CPU_STATUS=$CPU_STATUS,MEMORY_STATUS=$MEMORY_STATUS" \
        >> "$LOG_FILE"

    echo "Data pemantauan disimpan di: $LOG_FILE"
}

# ==========================================
# PROGRAM UTAMA
# ==========================================

case "${1:-}" in

    --watch)
        echo "Memulai pemantauan secara berkelanjutan..."
        echo "Tekan CTRL+C untuk menghentikan."

        while true; do
            monitor_system
            sleep "$INTERVAL"
        done
        ;;

    "")
        monitor_system
        ;;

    *)
        echo "Argumen tidak valid."
        echo "Penggunaan:"
        echo "./monitoring.sh"
        echo "./monitoring.sh --watch"
        exit 1
        ;;
esac
