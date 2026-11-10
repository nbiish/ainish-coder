#!/usr/bin/env bash
# Installs protoc (binary + well-known .proto includes) into ~/.local so the Rust engine builds on
# Linux/WSL without root.
#
# Why this exists: lancedb 0.41's build scripts run prost-build, which needs `protoc` *and*
# `google/protobuf/*.proto`. Installing only the binary produces
# "google/protobuf/empty.proto: File not found at encodings_v2_0.proto:8:1", which reads like a
# code error and is not one.
set -u

PROTOC_VERSION="${PROTOC_VERSION:-29.3}"
BIN="$HOME/.local/bin"
INC="$HOME/.local/include"
ZIP="/tmp/protoc-${PROTOC_VERSION}.zip"
DIST="/tmp/protoc-${PROTOC_VERSION}-dist"

mkdir -p "$BIN" "$INC"

if [ ! -x "$BIN/protoc" ]; then
    echo "Downloading protoc ${PROTOC_VERSION}..."
    if ! curl -fsSL -o "$ZIP" \
        "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip"; then
        echo "download failed; install protobuf-compiler with your package manager instead" >&2
        exit 1
    fi
    mkdir -p "$DIST"
    if command -v unzip >/dev/null 2>&1; then
        unzip -o -q "$ZIP" -d "$DIST"
    else
        python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$ZIP" "$DIST"
    fi
    cp "$DIST/bin/protoc" "$BIN/" && chmod +x "$BIN/protoc"
fi

# The well-known types live beside the binary in the release archive and must be kept: /tmp does not
# survive a reboot, so they are copied into ~/.local/include.
if [ ! -d "$INC/google/protobuf" ] && [ -d "$DIST/include/google/protobuf" ]; then
    cp -r "$DIST/include/google" "$INC/"
fi

echo "protoc      : $("$BIN/protoc" --version 2>&1)"
echo "include dir : $INC"
if [ -f "$INC/google/protobuf/empty.proto" ]; then
    echo "empty.proto : present"
else
    echo "empty.proto : MISSING — the build will fail at encodings_v2_0.proto" >&2
    exit 1
fi

cat > "$HOME/.ainish-protoc-env" <<EOF
# Sourced by scripts/build-rust-linux.sh so prost-build finds protoc and its includes.
export PROTOC="$BIN/protoc"
export PROTOC_INCLUDE="$INC"
export PATH="$BIN:\$PATH"
EOF
echo "env file    : $HOME/.ainish-protoc-env"
