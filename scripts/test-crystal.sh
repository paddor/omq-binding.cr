#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

cargo_cmd="${CARGO:-cargo}"
crystal_bin="${OMQ_CRYSTAL:-crystal}"
omq_rs_dir="${OMQ_RS_DIR:-$repo_root/../omq.rs}"

if [ ! -f "$omq_rs_dir/Cargo.toml" ]; then
    echo "OMQ_RS_DIR must point to an omq.rs checkout" >&2
    exit 1
fi

(cd "$omq_rs_dir" && "$cargo_cmd" build -p omq-libzmq)

case "$(uname -s)" in
    Darwin)
        dylib_var="DYLD_LIBRARY_PATH"
        ;;
    *)
        dylib_var="LD_LIBRARY_PATH"
        ;;
esac

lib_dir="$omq_rs_dir/target/debug"
export LIBRARY_PATH="$lib_dir${LIBRARY_PATH:+:$LIBRARY_PATH}"
export CRYSTAL_LIBRARY_PATH="$lib_dir${CRYSTAL_LIBRARY_PATH:+:$CRYSTAL_LIBRARY_PATH}"
export "$dylib_var=$lib_dir${!dylib_var:+:${!dylib_var}}"

"$crystal_bin" tool format --check src spec scripts
"$crystal_bin" spec spec --link-flags "-L$lib_dir -Wl,-rpath,$lib_dir"
