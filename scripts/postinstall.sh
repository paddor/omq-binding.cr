#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
omq_rs_url="${OMQ_RS_GIT:-https://github.com/paddor/omq.rs.git}"
omq_rs_ref="${OMQ_RS_REF:-main}"
cargo_cmd="${CARGO:-cargo}"

if [ "${OMQ_RS_DIR:-}" ]; then
    omq_rs_dir="$OMQ_RS_DIR"
elif [ -d "$repo_root/../omq.rs/.git" ]; then
    omq_rs_dir="$repo_root/../omq.rs"
else
    omq_rs_dir="$repo_root/ext/omq.rs"
    mkdir -p "$repo_root/ext"
    if [ -d "$omq_rs_dir/.git" ]; then
        git -C "$omq_rs_dir" fetch --depth 1 origin "$omq_rs_ref"
        git -C "$omq_rs_dir" checkout --detach FETCH_HEAD
    elif ! git clone --depth 1 --branch "$omq_rs_ref" "$omq_rs_url" "$omq_rs_dir"; then
        git clone --filter=blob:none --no-checkout "$omq_rs_url" "$omq_rs_dir"
        git -C "$omq_rs_dir" fetch --depth 1 origin "$omq_rs_ref"
        git -C "$omq_rs_dir" checkout --detach FETCH_HEAD
    fi
fi

if [ ! -f "$omq_rs_dir/Cargo.toml" ]; then
    echo "OMQ_RS_DIR must point to an omq.rs checkout" >&2
    exit 1
fi

(cd "$omq_rs_dir" && "$cargo_cmd" build -p omq-libzmq --release --locked)

case "$(uname -s)" in
    Darwin)
        lib_name="libomq_zmq.dylib"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        lib_name="omq_zmq.dll"
        ;;
    *)
        lib_name="libomq_zmq.so"
        ;;
esac

mkdir -p "$repo_root/ext/lib"
cp "$omq_rs_dir/target/release/$lib_name" "$repo_root/ext/lib/$lib_name"
