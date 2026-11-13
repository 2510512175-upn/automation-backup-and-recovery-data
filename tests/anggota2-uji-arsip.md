# Pengujian Anggota 2: Pembuatan Arsip

Penanggung jawab: Muhammad Agung (2510512181). Bukti: `evidence/anggota2-uji-arsip.txt`.

| Item | T04 (positif) | T05 (negatif) |
|---|---|---|
| Tujuan | Arsip terbentuk dan isinya sesuai | Tujuan tidak dapat ditulis, kegagalan dilaporkan |
| Prasyarat | Folder sumber berisi a.txt dan b.txt; folder tujuan dapat ditulis | Folder tujuan diberi izin 555 |
| Langkah | `bash scripts/backup.sh <sumber> <tujuan>` | Sama, dengan tujuan folder izin 555 |
| Hasil diharapkan | Exit 0, arsip izin 600, isi sama dengan sumber | Exit bukan 0, pesan error, tidak ada arsip |
| Hasil aktual | Exit 0, izin `-rw-------`, isi sama (diff) | Exit 1, "Folder tujuan tidak dapat ditulis", tidak ada arsip |
| Status | Lulus | Lulus |
| Pemulihan | Hapus /tmp/uji | `chmod 755` pada folder tujuan |

Catatan: pada T05 kegagalan ditangkap oleh pemeriksaan folder tujuan
sebelum `tar` dijalankan, sehingga cabang kegagalan `tar` tidak diuji.

## Uji akses (T17, T18)

| Item | T17 (positif) | T18 (negatif) |
|---|---|---|
| Tujuan | Akun berwenang dapat mengakses arsip | Akun tidak berwenang ditolak |
| Prasyarat | Arsip berizin 600 milik agung; akun `penguji` dibuat | Sama |
| Langkah | `tar -tzf` sebagai agung | `sudo -u penguji tar -tzf` |
| Hasil diharapkan | Daftar isi tampil, exit 0 | Permission denied, exit bukan nol |
| Hasil aktual | Daftar isi tampil (data/, a.txt, b.txt), exit 0 | `Cannot open: Permission denied`, exit 2 |
| Status | Lulus | Lulus |
| Pemulihan | `sudo deluser --remove-home penguji` | Sama |

Bukti: `evidence/anggota2-uji-akses.txt`. Uji ini dikerjakan oleh Agung
karena anggota yang ditugaskan membantu belum terlibat.