#!/usr/bin/env bash
# Menjalankan regression suite lokal untuk modul inti, lock/log/report, dan monitoring.

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

printf '=== Pemeriksaan sintaks seluruh script ===\n'
for script in "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/tests/*.sh; do
    bash -n "$script"
    printf '[LULUS] Sintaks %s valid.\n' "${script#"$ROOT_DIR"/}"
done

printf '\n=== Integrasi validasi, backup, checksum, dan restore ===\n'
bash "$ROOT_DIR/tests/test-core-integration.sh"

printf '\n=== Keamanan path backup ===\n'
bash "$ROOT_DIR/tests/test-backup-path-safety.sh"

printf '\n=== Lock, log, dan laporan ===\n'
bash "$ROOT_DIR/tests/test-izzul-lock-log-report.sh"

printf '\n=== Monitoring proses ===\n'
bash "$ROOT_DIR/tests/test-monitoring-rafif.sh"

printf '\nSemua regression test lokal yang tersedia selesai. Docker T13-T14 dan pengujian VM Ubuntu tetap dilakukan terpisah.\n'
