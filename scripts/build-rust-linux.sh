#!/usr/bin/env bash
# Builds the Rust engine on Linux (native or WSL) without requiring root.
#
# Two system dependencies are needed and neither is guaranteed on a workstation:
#   * protoc + the well-known google/protobuf/*.proto includes — lancedb 0.41's build scripts run
#     prost-build, which fails with "Could not find protoc" or "google/protobuf/empty.proto: File
#     not found" depending on which half is missing.
#   * a C toolchain (cc). rustls removed the OpenSSL requirement: the crate no longer links system
#     OpenSSL, so `libssl-dev` is NOT needed on any platform.
#
# Run scripts/install-protoc-wsl.sh once to place protoc and the includes under ~/.local.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../src/rag" || exit 1

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# shellcheck disable=SC1091
[ -f "$HOME/.ainish-protoc-env" ] && . "$HOME/.ainish-protoc-env"

if ! command -v protoc >/dev/null 2>&1; then
    echo "protoc not found. Run: bash scripts/install-protoc-wsl.sh" >&2
    echo "(lancedb 0.41 needs protoc AND the well-known proto includes)" >&2
    exit 1
fi
if [ -z "${PROTOC_INCLUDE:-}" ]; then
    echo "PROTOC_INCLUDE unset; source \$HOME/.ainish-protoc-env first" >&2
    exit 1
fi

echo "protoc  : $(command -v protoc) ($(protoc --version 2>&1))"
echo "includes: $PROTOC_INCLUDE"
echo "rustc   : $(rustc --version 2>&1)"
exec cargo build --release --message-format short
