#include "engine.h"
#include "lapi.h"

namespace lua
{
    lua_State *L;

    /*****************************
     * Lua callback system       *
     *****************************/

    /**
     * Name -> lua registry index
     */
    hashtable<const char *, int> externals;

    bool pushEvent(const char *name)
    {
        int *ref = externals.access(name);

        if(ref)
        {
            lua_rawgeti(L, LUA_REGISTRYINDEX, *ref);
            return true;
        }

        ref = externals.access("event.none");

        if(ref)
        {
            lua_rawgeti(L, LUA_REGISTRYINDEX, *ref);
            lua_pushstring(L, name);
            lua_call(L, 1,0);
        }

        return false;
    }

    /** 
     * Lua exposed command to set callbacks
     */
    static int setCallback(lua_State *L)
    {
        const char *name = luaL_checkstring(L, 1);
        int *ref = externals.access(name);
        if (ref)
        {
            lua_rawgeti(L, LUA_REGISTRYINDEX, *ref);
            luaL_unref (L, LUA_REGISTRYINDEX, *ref);
        }
        else
        {
            lua_pushnil(L);
        }
        /* let's pin the name so the garbage collector doesn't free it */
        lua_pushvalue(L, 1); lua_setfield(L, LUA_REGISTRYINDEX, name);
        /* and now we can ref */
        lua_pushvalue(L, 2);
        externals.access(name, luaL_ref(L, LUA_REGISTRYINDEX));
        return 1;
    }

    void createArgumentsTable(lua_State *L, int argc, const char **argv)
    {
        lua_pushstring(L, "argv");
        lua_createtable (L, argc, 0);
        
        for (int index = 0; index < argc; index++)
        {
            lua_pushstring (L, argv[index]);
            lua_rawseti(L, -2, index);
        }
        
        lua_rawset(L, LUA_GLOBALSINDEX);
    }

    bool init(int argc, const char **argv)
    {
        L = luaL_newstate();

        luaL_openlibs(L);

        createArgumentsTable(L, argc, argv);

        uv_loop_t *loop = uv_default_loop();

        #ifdef USE_OPENSSL
        luvit_init_ssl();
        #endif

        lua_newtable(L);
        lua_setfield(L, LUA_REGISTRYINDEX, "__pinstrs");

        if (luvit_init(L, loop))
        {
            fprintf(stderr, "luvit_init has failed\n");
            return false;
        }

        lua_pushcfunction(L, setCallback);
        lua_setglobal(L, "setCallback");

        ASSERT(0 == luaL_dostring(L, "package.path = package.path .. \";resources/lua/?.lua;resources/lua/?/init.lua\""));

        return true;
    }

    void close()
    {
        lua_close(L);
        L = NULL;
    }

    /**
     * Pushes the pinned string on the stack
     * \internal
     */
    inline void pushPinnedString(const char *string)
    {
        lua_pushliteral(L, "__pinstrs"); // __pinstrs 
        lua_rawget (L, LUA_REGISTRYINDEX); // _G["__pinstrs"]
        
        lua_pushstring (L, string); // _G["__pinstrs"], string 
        lua_pushvalue (L, -1); // _G["__pinstrs"], string, string
        
        lua_rawget (L, -3); // _G["__pinstrs"], string, _G["__pinstrs"][string]
    }
    
    void pinString(const char *string)
    {
        pushPinnedString(string);
        
        int count = lua_tointeger(L, -1);
        
        lua_pop(L, 1); //_G["__pinstrs"], string
        
        lua_pushinteger(L, count + 1); //_G["__pinstrs"], string, _G["__pinstrs"][string]+1
        
        lua_rawset(L, -3); // _G["__pinstrs"][string]
        lua_pop(L, 1); //
    }
    
    void unPinString(const char *string)
    {
        pushPinnedString(string);
        ASSERT(lua_isnumber(L, -1));
        
        int count = lua_tointeger(L, -1);
        
        lua_pop(L, 1); //_G["__pinstrs"], string
        
        if (count == 1)
        {
            lua_pushnil(L); //_G["__pinstrs"], string, nil
        }
        else
        {
            lua_pushinteger(L, count - 1); //_G["__pinstrs"], string, _G["__pinstrs"][string]-1
        }
        
        lua_rawset(L, -3); // _G["__pinstrs"]
        lua_pop(L, 1); //
    }
}