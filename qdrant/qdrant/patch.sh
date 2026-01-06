#/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <context name>"
    exit 1
fi

context="$1"

echo "patching ..."

sed -i '/target_arch == "aarch64"/i\
    } else if target_arch == "loongarch64" {\
        return' $context/lib/quantization/build.rs

sed -i '/const MIN_DIM_SIZE_SIMD: usize = 16;/a\
\
#[cfg(target_arch = "loongarch64")]\
pub(crate) const MIN_DIM_SIZE_SIMD: usize = usize::MAX;' $context/lib/segment/src/spaces/simple.rs

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
    }' $context/src/common/telemetry_ops/app_telemetry.rs

sed -i 's/target_arch = "aarch64"/target_arch = "aarch64", target_arch = "loongarch64"/' $context/src/common/telemetry_ops/memory_telemetry.rs

sed -i 's/target_arch = "aarch64"/target_arch = "aarch64", target_arch = "loongarch64"/' $context/Cargo.toml

echo "done"
