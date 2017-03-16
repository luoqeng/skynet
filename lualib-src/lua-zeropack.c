/*
    lua-zeropack.c
    Pack 0 in binaries.
*/

#define LUA_LIB

#include <string.h>
#include <stdint.h>

#include <lua.h>
#include <lauxlib.h>
#include "skynet_malloc.h"

#define INIT_BUFFER_SZ  1024
#define GROUP_SZ        8

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
lpack(lua_State *l) {
    size_t sz = 0;
    const uint8_t* ptr = (const uint8_t *)luaL_checklstring(l, 1, &sz);
    if (ptr == NULL || sz == 0) {
        return luaL_error(l, "Invalid or null string.");
    }
    uint8_t *packed = NULL;
    size_t idx = 0;
    size_t szfree = 0, sztotal = 0;
    int i;
    while(idx < sz) {
        uint8_t mapz = 0, len = 1;
        uint8_t group[9] = { 0 };
        for (i = 0; i < GROUP_SZ && idx < sz; ++i) {
            if (ptr[idx] != 0) {
                mapz |= ((1 << i) & 0xff);
                group[len++] = ptr[idx];
            }
            ++idx;
        }
        group[0] = mapz;
        if (append(&packed, &szfree, &sztotal, (uint8_t *)group, len)) {
            return luaL_error(l, "Not enough memory.");
        }
    }
    // If it is an unsaturated group, then fill a byte of free size.
    if (i < GROUP_SZ) {
        uint8_t fill = GROUP_SZ - i;
        if (append(&packed, &szfree, &sztotal, &fill, 1)) {
            return luaL_error(l, "Not enough memory.");
        }
    }
    lua_pushlstring(l, (const char *)packed, (sztotal - szfree) * sizeof(uint8_t));
    skynet_free(packed);
    return 1;
}

static int 
lunpack(lua_State *l) {
    size_t sz = 0;
    const uint8_t* ptr = (const uint8_t *)luaL_checklstring(l, 1, &sz);
    if (ptr == NULL || sz == 0) {
        return luaL_error(l, "Invalid or null string.");
    }
    uint8_t *origin = NULL;
    size_t idx = 0;
    size_t szfree = 0, sztotal = 0;
    while(idx < sz) {
        uint8_t mapz = ptr[idx++];
        uint8_t group[GROUP_SZ] = { 0 };
        uint8_t fill = 0;
        for (int i = 0; i < GROUP_SZ && idx < sz; ++i) {
            if (mapz & ((1 << i) & 0xff)) {
                group[i] = ptr[idx++];
            }
        }
        // To judge whether it is a unsaturated group.
        if (idx == sz - 1 && ptr[idx] < GROUP_SZ) {
            fill = ptr[idx++];
        }
        if (append(&origin, &szfree, &sztotal, (uint8_t *)group, GROUP_SZ - fill)) {
            return luaL_error(l, "Not enough memory.");
        }
    }
    lua_pushlstring(l, (const char *)origin, (sztotal - szfree) * sizeof(uint8_t));
    skynet_free(origin);
    return 1;
}

LUAMOD_API int 
luaopen_zeropack(lua_State *l) {
    luaL_checkversion(l);
    luaL_Reg lib[] = {
        { "pack", lpack },
        { "unpack", lunpack },
        { NULL, NULL }
    };
    luaL_newlib(l, lib);
    return 1;
}