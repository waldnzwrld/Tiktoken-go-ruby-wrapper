#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

typedef void (*GoProfileFn)(char*, char*, long*, int, int);

int main() {
    void* handle = dlopen("ext/libttwrapper.so", RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "Error: %s\n", dlerror());
        return 1;
    }

    GoProfileFn goProfile = (GoProfileFn)dlsym(handle, "goProfile");
    if (!goProfile) {
        fprintf(stderr, "Error: %s\n", dlerror());
        dlclose(handle);
        return 1;
    }

    char* encoding_type = strdup("cl100k_base");
    char* text = strdup("The quick brown fox jumps over the lazy dog");
    long numTokens = 100000;

    goProfile(encoding_type, text, &numTokens, 15000, 1);

    free(encoding_type);
    free(text);

    dlclose(handle);
    return 0;
}
