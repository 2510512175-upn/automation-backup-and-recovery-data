# Hasil Pengujian Modul Validasi

## Lingkungan Pengujian
- Sistem Operasi: CachyOS
- Shell: Bash
- Pengujian pengguna: Akun utama dan non-root

## Hasil Pengujian

| ID | Skenario | Exit Status | Hasil |
|---|---|---:|---|
| T01 | Sumber dan tujuan valid | 0 | Lulus |
| T02 | Sumber tidak ditemukan | 3 | Lulus |
| T03 | Parameter tidak diberikan | 2 | Lulus |
| T04 | Parameter kosong | 2 | Lulus |
| T05 | Sumber bukan direktori | 3 | Lulus |
| T06 | Tujuan tidak ditemukan | 5 | Lulus |
| T07 | Sumber tidak dapat dibaca | 4 | Lulus |
| T08 | Tujuan tidak dapat ditulis | 6 | Lulus |
| T09 | Pengujian akun non-root | 0 | Lulus |
| T10 | Sumber tidak dapat diakses oleh non-root | 4 | Lulus |
| T11 | Tujuan tidak dapat ditulis oleh non-root | 6 | Lulus |

## Kesimpulan

Modul validasi berhasil menjalankan pemeriksaan
parameter, keberadaan direktori, tipe direktori,
dan hak akses pengguna.

Pengujian dilakukan menggunakan akun utama
dan akun non-root.
