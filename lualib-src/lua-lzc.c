/*
lua-lzc.c
A lua zero compress library for sproto.
*/

#include <string.h>
#include <stdint.h>

#include <lua.h>
#include <lauxlib.h>
#include "skynet_malloc.h"

#define INIT_BUFFER_SZ  1024

static int
append(uint8_t **dst, size_t *szfree, size_t *sztotal, uint8_t *src, size_t sz) {
    if (*dst == NULL) {
        *dst = (uint8_t *)skynet_malloc(INIT_BUFFER_SZ * sizeof(uint8_t));
        if (*dst == NULL) {
            return 1;
        }
        *szfree = INIT_BUFFER_SZ * sizeof(uint8_t);
        *sztotal = INIT_BUFFER_SZ * sizeof(uint8_t);
    }
    if (*szfree < sz) {
        *sztotal += (sz + INIT_BUFFER_SZ) * sizeof(uint8_t);
        *dst = (uint8_t *)skynet_realloc(*dst, *sztotal);
        if (*dst == NULL) {
            return 1;
        }
        *szfree += (sz + INIT_BUFFER_SZ) * sizeof(uint8_t);
    }
    memcpy(*dst + *sztotal - *szfree, src, sz);
    *szfree -= sz;
    return 0;
}

static int 
lcompress(lua_State *l) {
    size_t sz = 0, ex = 0;
    const char* ptr = luaL_checklstring(l, 1, &sz);
    if (ptr == NULL || sz == 0) {
        return luaL_error(l, "Invalid or null string.");
    }
    if (sz % 8 != 0) {
        ex = 4;
    }
    uint8_t* origin = (uint8_t *)skynet_malloc((sz + ex) * sizeof(uint8_t));
    if (origin == NULL) {
        return luaL_error(l, "Not enough memory.");
    }
    memset(origin, 0, (sz + ex) * sizeof(uint8_t));
    memcpy(origin, ptr, sz);

    size_t idx = 0;
    uint8_t *compressed = NULL;
    size_t szfree = 0, sztotal = 0;
    while(idx < sz + ex) {
        uint8_t mapz = 0, len = 1;
        uint8_t group[9] = { 0 };
        for (int i = 0; i < 8; ++i) {
            if (origin[idx] != 0) {
                mapz |= ((1 << i) & 0xff);
                group[len++] = origin[idx];
            }
            ++idx;
        }
        group[0] = mapz;
        if (append(&compressed, &szfree, &sztotal, (uint8_t *)group, len)) {
            return luaL_error(l, "Not enough memory.");
        }
    }
    lua_pushlstring(l, (const char *)compressed, (sztotal - szfree) * sizeof(uint8_t));
    skynet_free(origin);
    skynet_free(compressed);
    return 1;
}

static int 
ldecompress(lua_State *l) {
    return 1;
}

int 
luaopen_lzc(lua_State *l) {
    luaL_checkversion(l);
    luaL_Reg lib[] = {
        { "compress", lcompress },
        { "decompress", ldecompress },
        { NULL, NULL }
    };
    luaL_newlib(l, lib);
    return 1;
}