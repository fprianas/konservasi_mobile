#!/bin/bash
clear
echo "=================================================="
echo "   KONSERVASI MINERBA - SETUP AWAL macOS"
echo "=================================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$SCRIPT_DIR/Konservasi Minerba.app"
APP_DEST="/Applications/Konservasi Minerba.app"

if [ -d "$APP_SRC" ]; then
  echo "[1/3] Menyalin Konservasi Minerba.app ke folder Applications..."
  rm -rf "$APP_DEST"
  cp -R "$APP_SRC" "$APP_DEST"
else
  echo "[!] Konservasi Minerba.app tidak ditemukan di sebelah script ini."
  echo "    Mengecek di /Applications..."
fi

if [ -d "$APP_DEST" ]; then
  echo "[2/3] Membuka izin keamanan macOS (xattr -cr)..."
  xattr -cr "$APP_DEST"
  echo "[3/3] Selesai! Membuka aplikasi Konservasi Minerba..."
  open "$APP_DEST"
else
  echo ""
  echo "GAGAL: Aplikasi belum ada di /Applications."
  echo "Silakan seret (drag) 'Konservasi Minerba.app' ke folder Applications terlebih dahulu."
fi

echo ""
read -p "Tekan Enter untuk menutup jendela ini..."
