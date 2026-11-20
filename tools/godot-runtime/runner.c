#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

/* The operator supplies immutable absolute paths and reviewed hashes at build. */
#ifndef GODOT_BINARY
#error GODOT_BINARY must be supplied
#endif
#ifndef GODOT_SHA256
#error GODOT_SHA256 must be supplied
#endif
#ifndef GUARD_LIBRARY
#error GUARD_LIBRARY must be supplied
#endif
#ifndef GUARD_SHA256
#error GUARD_SHA256 must be supplied
#endif

static int matches_hash(const char *file, const char *expected) {
    int descriptors[2];
    if (pipe(descriptors) != 0) return 0;
    pid_t child = fork();
    if (child < 0) { close(descriptors[0]); close(descriptors[1]); return 0; }
    if (child == 0) {
        close(descriptors[0]);
        if (dup2(descriptors[1], STDOUT_FILENO) < 0) _exit(127);
        close(descriptors[1]);
        execl("/usr/bin/timeout", "timeout", "15s", "/usr/bin/sha256sum", "--", file, (char *)NULL);
        _exit(127);
    }
    close(descriptors[1]);
    FILE *output = fdopen(descriptors[0], "r");
    char digest[65] = {0};
    int parsed = 0;
    if (output) { parsed = fscanf(output, "%64[0-9a-f]", digest); fclose(output); }
    else close(descriptors[0]);
    int status = 0;
    pid_t waited;
    do { waited = waitpid(child, &status, 0); } while (waited < 0 && errno == EINTR);
    return waited == child && WIFEXITED(status) && WEXITSTATUS(status) == 0 &&
           parsed == 1 && strlen(digest) == 64 && strcmp(digest, expected) == 0;
}

int main(int argc, char **argv) {
    (void)argc;
    const char *existing = getenv("LD_PRELOAD");
    if (existing && *existing) {
        fputs("GODOT_RUNTIME_FAIL: unexpected existing LD_PRELOAD\n", stderr);
        return 3;
    }
    if (!matches_hash(GODOT_BINARY, GODOT_SHA256) || !matches_hash(GUARD_LIBRARY, GUARD_SHA256)) {
        fputs("GODOT_RUNTIME_FAIL: engine or guard hash mismatch; run reviewed preparation\n", stderr);
        return 3;
    }
    if (setenv("LD_PRELOAD", GUARD_LIBRARY, 1) != 0) return 3;
    argv[0] = GODOT_BINARY;
    execv(GODOT_BINARY, argv);
    perror("GODOT_RUNTIME_FAIL: exec");
    return 3;
}
