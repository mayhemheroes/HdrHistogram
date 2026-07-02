#!/usr/bin/env bash
#
# mayhem/build.sh — build HdrHistogram (Maven), the LogReaderWriterFuzzer Jazzer harness,
# ELF launcher shims (Mayhem requires ELF cmd targets with DWARF < 4), and pre-compile the
# JUnit test suite for mayhem/test.sh.
#
# AIR-GAPPED CONTRACT (SPEC §6.5): the PATCH tier re-runs THIS script OFFLINE. The first (online)
# build populates /opt/toolchains/jvm/m2-repository; subsequent offline runs resolve Maven deps
# entirely from that cache.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC MAYHEM_JOBS
echo "SANITIZER_FLAGS=${SANITIZER_FLAGS} (JVM fuzzing via Jazzer; applied to ELF launcher shims only)"

SRC="${SRC:-/mayhem}"
OUT="/mayhem"
JVM_PREFIX="${JVM_PREFIX:-/opt/toolchains/jvm}"
MAVEN_HOME="${MAVEN_HOME:-/opt/toolchains/maven}"
MVN="${MVN:-$MAVEN_HOME/bin/mvn}"
JAVA_HOME="${JAVA_HOME:-/opt/toolchains/jvm/jdk}"
JAZZER_DRIVER="$JVM_PREFIX/jazzer_driver"
JAZZER_STANDALONE="$JVM_PREFIX/jazzer_standalone.jar"
M2_REPO="$JVM_PREFIX/m2-repository"

export JAVA_HOME PATH="$MAVEN_HOME/bin:$JAVA_HOME/bin:$PATH"
export MAVEN_OPTS="-Dmaven.repo.local=$M2_REPO"

cd "$SRC"
mkdir -p "$M2_REPO" "$SRC/mayhem-build"

echo "=== java/maven ==="
java -version
"$MVN" -version

# 1) Build the project jar (online first pass fills M2_REPO; offline re-run uses --offline).
MAVEN_OFFLINE=()
if [ -d "$M2_REPO/org" ] && [ -n "$(ls -A "$M2_REPO/org" 2>/dev/null || true)" ]; then
  MAVEN_OFFLINE=(--offline)
fi

echo "=== mvn package (project jar for fuzzing) ==="
"$MVN" -B "${MAVEN_OFFLINE[@]}" \
  -Djavac.src.version=17 -Djavac.target.version=17 \
  -DskipTests package

cp -f HdrHistogram.jar "$OUT/HdrHistogram-lib.jar"

echo "=== mvn test-compile (JUnit suite for test.sh) ==="
"$MVN" -B "${MAVEN_OFFLINE[@]}" \
  -Djavac.src.version=17 -Djavac.target.version=17 \
  test-compile

echo "=== compile LogReaderWriterFuzzer harness ==="
javac -cp "$OUT/HdrHistogram-lib.jar:$JAZZER_STANDALONE" mayhem/LogReaderWriterFuzzer.java
cp -f mayhem/LogReaderWriterFuzzer.class "$OUT/LogReaderWriterFuzzer.class"

install -m 644 "$JAZZER_STANDALONE" "$OUT/jazzer_standalone.jar"

compile_launcher() {
  local out="$1" mode="$2"
  echo "=== compiling /mayhem/$out (mode=$mode) ==="
  "$CC" $DEBUG_FLAGS -O1 \
    -DJAZZER_DRIVER="\"$JAZZER_DRIVER\"" \
    -DJVM_LD_LIBRARY_PATH="\"${JVM_LD_LIBRARY_PATH:-$JAVA_HOME/lib/server}\"" \
    -DFUZZ_CP="\"$OUT/HdrHistogram-lib.jar:$OUT\"" \
    -DFUZZ_TARGET="\"LogReaderWriterFuzzer\"" \
    -DLAUNCHER_MODE="$mode" \
    -o "$OUT/$out" mayhem/jazzer_launcher.c
  chmod +x "$OUT/$out"
}

# mode 0 = LogReaderWriterFuzzer (libFuzzer loop)
# mode 1 = bare jazzer_driver passthrough (not fuzz-smoke-able; kept as mode 0 for Mayhem)
# mode 2 = LogReaderWriterFuzzer standalone (single run reproducer)
compile_launcher LogReaderWriterFuzzer 0
compile_launcher jazzer_driver 0
compile_launcher LogReaderWriterFuzzer-standalone 2

# OSS-Fuzz copies HdrHistogram.jar into $OUT alongside the fuzzer wrapper — keep the same
# artifact name for parity (ELF launcher, not the library jar).
install -m 755 "$OUT/LogReaderWriterFuzzer" "$OUT/HdrHistogram.jar"

echo "=== compiling /mayhem/hdrhistogram-tests (mvn surefire wrapper) ==="
"$CC" $DEBUG_FLAGS -O1 \
  -DMVN="\"$MVN\"" \
  -o "$OUT/hdrhistogram-tests" mayhem/run_tests.c
chmod +x "$OUT/hdrhistogram-tests"

echo "build.sh complete:"
ls -la "$OUT/LogReaderWriterFuzzer" "$OUT/jazzer_driver" "$OUT/LogReaderWriterFuzzer-standalone" \
       "$OUT/hdrhistogram-tests" "$OUT/HdrHistogram-lib.jar" "$OUT/LogReaderWriterFuzzer.class"
