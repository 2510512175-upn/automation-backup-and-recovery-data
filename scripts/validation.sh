#!/bin/bash

# Validasi jumlah parameter
if [[ $# -ne 2 ]]; then
    echo "Error: Parameter harus terdiri dari sumber dan tujuan."
    exit 2
fi

SOURCE="$1"
DESTINATION="$2"

# Validasi parameter kosong
if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
    echo "Error: Parameter tidak boleh kosong."
    exit 2
fi

# Validasi keberadaan sumber
if [[ ! -e "$SOURCE" ]]; then
    echo "Error: Direktori sumber tidak ditemukan."
    exit 3
fi

# Validasi tipe sumber
if [[ ! -d "$SOURCE" ]]; then
    echo "Error: Sumber bukan direktori."
    exit 3
fi

# Validasi izin baca sumber
if [[ ! -r "$SOURCE" || ! -x "$SOURCE" ]]; then
    echo "Error: Direktori sumber tidak dapat diakses."
    exit 4
fi

# Validasi keberadaan tujuan
if [[ ! -e "$DESTINATION" ]]; then
    echo "Error: Direktori tujuan tidak ditemukan."
    exit 5
fi

# Validasi tipe tujuan
if [[ ! -d "$DESTINATION" ]]; then
    echo "Error: Tujuan bukan direktori."
    exit 5
fi

# Validasi izin tulis tujuan
if [[ ! -w "$DESTINATION" || ! -x "$DESTINATION" ]]; then
    echo "Error: Direktori tujuan tidak dapat ditulis."
    exit 6
fi

echo "Validasi berhasil."
echo "Sumber: $SOURCE"
echo "Tujuan: $DESTINATION"

exit 0