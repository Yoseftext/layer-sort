#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <stddef.h>
#include <string.h>

/* Godot ed1daf0bf camera_linux.cpp frees an uninitialized list when /dev
 * discovery fails. Preserve the denial; normalize only that failed output.
 * This library is invocation-scoped, never installed in the global loader. */
#define DEFINE_GUARD(name, entry_type) \
int name(const char *directory, struct entry_type ***entries, \
         int (*filter)(const struct entry_type *), \
         int (*compare)(const struct entry_type **, const struct entry_type **)) { \
    typedef int (*scan_fn)(const char *, struct entry_type ***, \
                          int (*)(const struct entry_type *), \
                          int (*)(const struct entry_type **, const struct entry_type **)); \
    const int incoming_errno = errno; \
    scan_fn next = (scan_fn)dlsym(RTLD_NEXT, #name); \
    if (!next) { \
        if (strcmp(directory, "/dev") == 0) *entries = NULL; \
        errno = ENOSYS; \
        return -1; \
    } \
    errno = incoming_errno; \
    int result = next(directory, entries, filter, compare); \
    const int call_errno = errno; \
    if (result < 0 && strcmp(directory, "/dev") == 0) *entries = NULL; \
    errno = call_errno; \
    return result; \
}

DEFINE_GUARD(scandir, dirent)
DEFINE_GUARD(scandir64, dirent64)
