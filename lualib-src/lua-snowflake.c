#include <stdint.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <sys/time.h>

#include <lua.h>
#include <lauxlib.h>

#define MAX_INDEX_VAL       0x0fff
#define MAX_WORKID_VAL      0x03ff
#define MAX_TIMESTAMP_VAL   0x01ffffffffff

typedef struct _t_ctx {
    pthread_mutex_t sync_policy;
    int64_t last_timestamp;
    int32_t work_id;
    int16_t index;
} ctx_t;

static ctx_t* g_ctx = NULL;

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
    } while (g_ctx->last_timestamp >= current_timestamp);
    g_ctx->last_timestamp = current_timestamp;
    g_ctx->index = 0;
}

static uint64_t
next_id() {
    if (!g_ctx) {
        return 0;
    }
    pthread_mutex_lock(&g_ctx->sync_policy);
    int64_t current_timestamp = get_timestamp();
    if (current_timestamp == g_ctx->last_timestamp) {
        if (g_ctx->index < MAX_INDEX_VAL) {
            ++g_ctx->index;
        } else {
            wait_next_msec();
        }
    } else {
        g_ctx->last_timestamp = current_timestamp;
        g_ctx->index = 0;
    }
    int64_t nextid = (int64_t)(
        ((g_ctx->last_timestamp & MAX_TIMESTAMP_VAL) << 22) | 
        ((g_ctx->work_id & MAX_WORKID_VAL) << 12) | 
        (g_ctx->index & MAX_INDEX_VAL)
    );
    pthread_mutex_unlock(&g_ctx->sync_policy);
    return nextid;
}

static ctx_t* 
unique_instance(uint16_t work_id) {
    if (g_ctx) {
        return g_ctx;
    }
    g_ctx = (ctx_t *)malloc(sizeof(ctx_t));
    if (!g_ctx) {
        return NULL;
    }
    g_ctx->work_id = work_id;
    g_ctx->index = 0;
    if (pthread_mutex_init(&g_ctx->sync_policy, NULL)) {
        free(g_ctx);
        g_ctx = NULL;
    }
    return g_ctx;
}

static void
destroy_instance() {
    if (g_ctx) {
        pthread_mutex_destroy(&g_ctx->sync_policy);
        free(g_ctx);
        g_ctx = NULL;
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
    if (!unique_instance(work_id)) {
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
    destroy_instance();
    return 0;
}

int
luaopen_snowflake(lua_State* l) {
    luaL_checkversion(l);
	luaL_Reg lib[] = {
        { "__gc", lfini },
		{ "init", linit },
		{ "next_id", lnextid },
		{ NULL, NULL }
	};
	luaL_newlib(l, lib);
	return 1;
}