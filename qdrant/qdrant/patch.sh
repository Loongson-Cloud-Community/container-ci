#/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <context name>"
    exit 1
fi

context="$1"
version="$context"

universal_patch()
{
    sed -i '/target_arch == "aarch64"/i\
    } else if target_arch == "loongarch64" {\
        return' "$context/lib/quantization/build.rs"

    sed -i '/const MIN_DIM_SIZE_SIMD: usize = 16;/a\
\
#[cfg(target_arch = "loongarch64")]\
pub(crate) const MIN_DIM_SIZE_SIMD: usize = usize::MAX;' "$context/lib/segment/src/spaces/simple.rs"

    sed -i '/target_arch = "aarch64"/i\
    #[cfg(target_arch = "loongarch64")]\
    {\
        if let Ok(cpuinfo) = std::fs::read_to_string("/proc/cpuinfo") {\
            for line in cpuinfo.lines() {\
                if line.starts_with("Features") || line.starts_with("features") ||\
                      line.starts_with("flags") || line.starts_with("Flags") {\
                    if let Some(colon_pos) = line.find('\'':'\'') {\
                        let flags_str = &line[colon_pos + 1..].trim();\
                        if flags_str.contains("lsx") {\
                            cpu_flags.push("lsx".to_string());\
                        }\
                        if flags_str.contains("lasx") {\
                            cpu_flags.push("lasx".to_string());\
                        }\
                        break;\
                    }\
                }\
            }\
        }\
    }' "$context/src/common/telemetry_ops/app_telemetry.rs"

    sed -i 's/target_arch = "aarch64"/target_arch = "aarch64", target_arch = "loongarch64"/' "$context/src/common/telemetry_ops/memory_telemetry.rs"

    sed -i 's/target_arch = "aarch64"/target_arch = "aarch64", target_arch = "loongarch64"/' "$context/Cargo.toml"
}


multi_version_patch()
{
    major_ver=$(echo "$version" | cut -d. -f1)
    minor_ver=$(echo "$version" | cut -d. -f2)
    patch_ver=$(echo "$version" | cut -d. -f3)
    ver_num=$(( 10#$major_ver * 1000000 + 10#$minor_ver * 1000 + 10#$patch_ver ))
    
    # 1.17.1 引入的 pprof-pyroscope-fork 期望 loongarch 和其他架构一样，在开启 frame-pointer 或者 framehop-unwinder 时使用 frame_pointer 模块
    # 该部分补丁让 loongarch 使用通用的 backtrace_rs 而不是 frame_pointer
    if [ "$ver_num" -ge 1017001 ] && [ "$ver_num" -lt 1018002 ]; then
	cat << 'EOF' > /tmp/insert_block
RUN cargo chef cook --profile $PROFILE ${FEATURES:+--features "$FEATURES"} --recipe-path recipe.json || true
RUN PPROF_MOD=$(find /usr/local/cargo/registry/src -name mod.rs | grep pprof-pyroscope-fork); \
    if [ -f "$PPROF_MOD" ]; then \
        sed -i "/loongarch64/d" "$PPROF_MOD"; \
    fi
EOF
        sed -i '/RUN cargo chef cook/e cat /tmp/insert_block' "$context/Dockerfile"
    fi


    # 1.18.2 无条件启用 pyroscope 的 backend-pprof-rs，后者的 2.0.6 版本内部硬编码 framehop_unwinder
    if [ "$ver_num" -ge 1018002 ]; then
        # 跳过 pyroscope 集成
        #skip_pyroscope
        # 使用已适配的 framehop 和 pyroscope-rs
        pyroscope_ver=$(awk '
  prev && /^version = "/ {
    sub(/^version = "/, "")
    sub(/"$/, "")
    print
    exit
  }
  /^name = "pyroscope"$/ { prev = 1; next }
  { prev = 0 }
' "$context/Cargo.lock")
        if grep -q '^[[:space:]]*\[patch\.crates-io\][[:space:]]*$' "$context/Cargo.toml"; then
            sed -i '/\[patch.crates-io\]/a\
pyroscope = { git = "https://github.com/Chris-wh233/pyroscope-rs-loongarch64.git", branch = "__PYROSCOPE_BRANCH__" }' "$context/Cargo.toml"
        else
            echo "[patch.crates-io]" >> "$context/Cargo.toml"
            echo "pyroscope = { git = "https://github.com/Chris-wh233/pyroscope-rs-loongarch64.git", branch = "__PYROSCOPE_BRANCH__" }" >> "$context/Cargo.toml"
        fi
        sed -i "s/__PYROSCOPE_BRANCH__/lib-$pyroscope_ver-loongarch64/" "$context/Cargo.toml"
    fi
}

skip_pyroscope()
{
    local pyroscope_line=$(grep 'pyroscope =' "$context/Cargo.toml")
    sed -i '/pyroscope = {/d' "$context/Cargo.toml"
    cat << EOF > /tmp/insert_block
[target.'cfg(all(target_os = "linux", any(target_arch = "x86_64", target_arch = "aarch64")))'.dependencies]
$pyroscope_line
EOF
    cat "/tmp/insert_block" >> "$context/Cargo.toml"

    sed -i 's/cfg(target_os = "linux")/cfg(all(target_os = "linux", any(target_arch = "x86_64", target_arch = "aarch64")))/' "$context/src/common/pyroscope_state.rs"
    sed -i 's/cfg(not(target_os = "linux"))/cfg(not(all(target_os = "linux", any(target_arch = "x86_64", target_arch = "aarch64"))))/' "$context/src/common/pyroscope_state.rs"
    sed -i 's/cfg(target_os = "linux")/cfg(all(target_os = "linux", any(target_arch = "x86_64", target_arch = "aarch64")))/' "$context/src/common/debugger.rs"
    sed -i 's/cfg(not(target_os = "linux"))/cfg(not(all(target_os = "linux", any(target_arch = "x86_64", target_arch = "aarch64"))))/' "$context/src/common/debugger.rs"
}

patch()
{
    echo "patching ..."
    universal_patch
    multi_version_patch
    echo "done"
}

patch
