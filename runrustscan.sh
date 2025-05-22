#!/bin/bash

# ========================
# CONFIG
# ========================
IMAGE_NAME="rustscan-arm64"
BIN_NAME="rustscan"
BIN_URL="https://github.com/bee-san/RustScan/releases/download/2.4.1/aarch64-linux-rustscan.zip"

# ========================
# CEK BINARY FILE
# ========================
if [ ! -f "$BIN_NAME" ]; then
    echo "[+] File $BIN_NAME tidak ditemukan. Download dari GitHub..."
    curl -L "$BIN_URL" -o rustscan.zip || {
        echo "[!] Gagal download file dari $BIN_URL"
        exit 1
    }

    unzip rustscan.zip || {
        echo "[!] Gagal ekstrak rustscan.zip"
        exit 1
    }

    chmod +x "$BIN_NAME"
    echo "[✓] Berhasil download & ekstrak binary."
fi

# ========================
# CEK DOCKER IMAGE
# ========================
IMAGE_EXISTS=$(docker images -q "$IMAGE_NAME")
if [ -n "$IMAGE_EXISTS" ]; then
    echo "[+] Docker image '$IMAGE_NAME' sudah ada. Skip build."
else
    echo "[+] Membuat Dockerfile dengan nmap support..."
    cat <<EOF > Dockerfile
FROM debian:bullseye-slim

RUN apt-get update && \\
    apt-get install -y nmap && \\
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY $BIN_NAME /usr/local/bin/rustscan
RUN chmod +x /usr/local/bin/rustscan

ENTRYPOINT ["rustscan"]
EOF

    echo "[+] Build Docker image: $IMAGE_NAME"
    docker build -t "$IMAGE_NAME" . || {
        echo "[!] Gagal build image."
        exit 1
    }
fi

# ========================
# PILIH MODE
# ========================
echo "Pilih mode pemindaian:"
echo "1) NMAP"
echo "2) RustScan (default)"
echo "3) Generate daftar IP dari CIDR (misal 10.16.8.8/16) ke file"
read -p "Pilihan Anda (1-3): " MODE

if [ "$MODE" == "1" ]; then
    read -p "Masukkan IP atau domain target untuk scan: " TARGET
    DEFAULT_NMAP_ARGS="-g53 --max-retries=1 -Pn -p- --disable-arp-ping -n -v"
    read -p "Masukkan argumen tambahan untuk Nmap (ENTER untuk default: $DEFAULT_NMAP_ARGS): " EXTRA_ARGS

    if [ -z "$EXTRA_ARGS" ]; then
        EXTRA_ARGS="$DEFAULT_NMAP_ARGS"
    fi

    echo "[+] Menjalankan NMAP untuk target: $TARGET"
    docker run --rm -it --entrypoint nmap "$IMAGE_NAME" $EXTRA_ARGS "$TARGET"
    exit 0
fi

if [ "$MODE" == "2" ] || [ -z "$MODE" ]; then
    read -p "Masukkan IP atau domain target untuk scan: " TARGET
    DEFAULT_RUSTSCAN_ARGS="-t 6000 -b 1000 -- -sCV -Pn -v"
    read -p "Masukkan argumen tambahan untuk RustScan (ENTER untuk default: $DEFAULT_RUSTSCAN_ARGS): " EXTRA_ARGS

    if [ -z "$EXTRA_ARGS" ]; then
        EXTRA_ARGS="$DEFAULT_RUSTSCAN_ARGS"
    fi

    echo "[+] Menjalankan RustScan untuk target: $TARGET"
    docker run --rm -it "$IMAGE_NAME" -a "$TARGET" $EXTRA_ARGS
    exit 0
fi

if [ "$MODE" == "3" ]; then
    read -p "Masukkan IP atau domain target untuk scan: " TARGET
    read -p "Masukkan subnet (misal /16): " CIDR_INPUT
    
    CIDR_RANGE="${TARGET}${CIDR_INPUT}"
    OUTPUT_FILE="${CIDR_RANGE}.txt"
    SAFE_OUTPUT_FILE="${OUTPUT_FILE//\//_}"  # Ganti '/' agar valid di nama file
    
    echo "[+] Cek IP aktif di $CIDR_RANGE (ini bisa makan waktu tergantung subnet)..."
    
    docker run --rm -i --entrypoint nmap "$IMAGE_NAME" -sL -n "$CIDR_RANGE" | \
    awk '/Nmap scan report for/ {print $NF}' | tee "$SAFE_OUTPUT_FILE"





    echo "[✓] IP aktif disimpan ke: $SAFE_OUTPUT_FILE"

    exit 0
fi
