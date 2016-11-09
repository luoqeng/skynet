#include <stdint.h>
#include <pthread.h>
#include <time.h>
#include <sys/time.h>

#include <lua.h>
#include <lauxlib.h>

#define LUA_SNOWFLAKE_METATABLE ("__lua_snowflake")

#define MAX_INDEX_VAL       0x0fff
#define MAX_WORKID_VAL      0x03ff
#define MAX_TIMESTAMP_VAL   0x01ffffffffff

typedef struct _t_ctx {
    pthread_mutex_t sync_policy;
    int64_t last_timestamp;
    int32_t work_id;
    int16_t index;
} ctx_t;

static int g_inited = 0;
static ctx_t g_ctx;

static int64_t
get_timestamp() {
	struct timeval tv;
	gettimeofday(&tv, 0);
	return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

static void
wait_next_msec() {
    int64_t current_timestamp = 0;
    do {
        current_timestamp = get_timestamp();
    } while (g_ctx.last_timestamp >= current_timestamp);
    g_ctx.last_timestamp = current_timestamp;
    g_ctx.index = 0;
}

static uint64_t
next_id() {
    if (!g_inited) {
        return -1;
    }
    pthread_mutex_lock(&g_ctx.sync_policy);
    int64_t current_timestamp = get_timestamp();
    if (current_timestamp == g_ctx.last_timestamp) {
        if (g_ctx.index < MAX_INDEX_VAL) {
            ++g_ctx.index;
        } else {
            wait_next_msec();
        }
    } else {
        g_ctx.last_timestamp = current_timestamp;
        g_ctx.index = 0;
    }
    int64_t nextid = (int64_t)(
        ((g_ctx.last_timestamp & MAX_TIMESTAMP_VAL) << 22) | 
        ((g_ctx.work_id & MAX_WORKID_VAL) << 12) | 
        (g_ctx.index & MAX_INDEX_VAL)
    );
    pthread_mutex_unlock(&g_ctx.sync_policy);
    return nextid;
}

static int
init(uint16_t work_id) {
    if (g_inited) {
        return 0;
    }
    g_ctx.work_id = work_id;
    g_ctx.index = 0;
    if (pthread_mutex_init(&g_ctx.sync_policy, NULL)) {
        return -1;
    }
    g_inited = 1;
    return 0;
}

static void
fini() {
    if (g_inited) {
        pthread_mutex_destroy(&g_ctx.sync_policy);
        g_inited = 0;
    }
}

static int
linit(lua_State* l) {
    int16_t work_id = 0;
    if (lua_gettop(l) > 0) {
        lua_Integer id = luaL_checkinteger(l, 1);
        if (id < 0 || id > MAX_WORKID_VAL) {
            return luaL_error(l, "Work id is in range of 0 - 1023.");
        }
        work_id = (int16_t)id;
    }
    if (init(work_id)) {
        return luaL_error(l, "Init instance error, not enough memory.");
    }
    lua_pushboolean(l, 1);
    return 1;
}

static int
lnextid(lua_State* l) {
    int64_t id = next_id();
    lua_pushinteger(l, (lua_Integer)id);
    return 1;
}

static int
lfini(lua_State* l) {
    fini();
    return 0;
}

luaL_Reg mtlib[] = {
    { "__gc", lfini },
    { NULL, NULL }
};

luaL_Reg lib[] = {
    { "init", linit },
    { "next_id", lnextid },
    { NULL, NULL }
};

int
luaopen_snowflake(lua_State* l) {
    luaL_checkversion(l);
    if (luaL_newmetatable(l, LUA_SNOWFLAKE_METATABLE)) {
        lua_pushvalue(l, -1);
        lua_setfield(l, -2, "__index");
        luaL_setfuncs(l, mtlib, 0);
        lua_pop(l, 1);
    }
    luaL_newlib(l, lib);
    luaL_getmetatable(l, LUA_SNOWFLAKE_METATABLE);
    lua_setmetatable(l, -2);
    return 1;
}