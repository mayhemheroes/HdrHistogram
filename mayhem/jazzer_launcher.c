/*
 * jazzer_launcher.c — ELF wrapper around the Jazzer native driver.
 *
 * Mayhem requires the target cmd to be an ELF (not a shell script) and our gate checks each
 * target binary for DWARF < 4 debug info. Jazzer itself is a prebuilt binary; we compile this
 * thin launcher (with $DEBUG_FLAGS / -gdwarf-3) and exec the real driver with the correct JVM
 * library path and fuzz-target arguments.
 *
 * LAUNCHER_MODE (compile-time):
 *   0 — LogReaderWriterFuzzer libFuzzer target
 *   1 — bare jazzer_driver (preserved target parity)
 *   2 — LogReaderWriterFuzzer standalone reproducer (-runs=1)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef JAZZER_DRIVER
#define JAZZER_DRIVER "/opt/toolchains/jvm/jazzer_driver"
#endif
#ifndef JVM_LD_LIBRARY_PATH
#define JVM_LD_LIBRARY_PATH "/opt/toolchains/jvm/jdk/lib/server"
#endif
#ifndef FUZZ_CP
#define FUZZ_CP "/mayhem/HdrHistogram-lib.jar:/mayhem"
#endif
#ifndef FUZZ_TARGET
#define FUZZ_TARGET "LogReaderWriterFuzzer"
#endif
#ifndef LAUNCHER_MODE
#define LAUNCHER_MODE 0
#endif

static void set_ld_library_path(void) {
    const char *cur = getenv("LD_LIBRARY_PATH");
    char buf[4096];
    if (cur && *cur) {
        snprintf(buf, sizeof(buf), "%s:%s", JVM_LD_LIBRARY_PATH, cur);
    } else {
        snprintf(buf, sizeof(buf), "%s", JVM_LD_LIBRARY_PATH);
    }
    setenv("LD_LIBRARY_PATH", buf, 1);
}

int main(int argc, char **argv) {
    set_ld_library_path();

#if LAUNCHER_MODE == 1
    char **a = (char **)calloc((size_t)argc + 2, sizeof(char *));
    if (!a) {
        perror("calloc");
        return 1;
    }
    int n = 0;
    a[n++] = (char *)JAZZER_DRIVER;
    for (int i = 1; i < argc; i++) {
        a[n++] = argv[i];
    }
    a[n] = NULL;
    execv(JAZZER_DRIVER, a);
#else
    char **a = (char **)calloc((size_t)argc + 8, sizeof(char *));
    if (!a) {
        perror("calloc");
        return 1;
    }
    int n = 0;
    a[n++] = (char *)JAZZER_DRIVER;
    a[n++] = (char *)"--cp=" FUZZ_CP;
    a[n++] = (char *)"--target_class=" FUZZ_TARGET;
    a[n++] = (char *)"--jvm_args=-Xmx2048m";
#if LAUNCHER_MODE == 2
    a[n++] = (char *)"-runs=1";
#endif
    for (int i = 1; i < argc; i++) {
        a[n++] = argv[i];
    }
    a[n] = NULL;
    execv(JAZZER_DRIVER, a);
#endif
    perror("execv " JAZZER_DRIVER);
    return 127;
}
