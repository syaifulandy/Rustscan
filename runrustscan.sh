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
# JALANKAN SCAN
# ========================
read -p "Masukkan IP atau domain target untuk scan: " TARGET

DEFAULT_ARGS="-t 6000 -b 1000 -- -sCV -Pn -v"
read -p "Masukkan argumen tambahan (ENTER untuk default: $DEFAULT_ARGS): " EXTRA_ARGS

if [ -z "$EXTRA_ARGS" ]; then
    EXTRA_ARGS="$DEFAULT_ARGS"
fi

echo "[+] Menjalankan RustScan untuk target: $TARGET"
docker run --rm -it "$IMAGE_NAME" -a "$TARGET" $EXTRA_ARGS

