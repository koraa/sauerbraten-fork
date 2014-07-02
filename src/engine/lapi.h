
extern "C"
{
    #include "lua.h"
    #include "lualib.h"
    #include "lauxlib.h"

    #include "uv.h" 
    #include "luvit/luvit_init.h"
}

namespace lua
{
    /**
    * The lua state
    */
    extern lua_State *L;

    /**
    * Pushes a lua event callback onto the stack.
    * 
    * \param name the name of the event.
    * \return whether a lua callback was found to be pushed.
    */
    extern bool pushEvent(const char *name);

    /**
     * Initializes the lua server state.
     */
    extern bool init(int argc, const char **argv);

    /**
     * Closes the current lua state
     */
    extern void close();

    /**
     * Pins a lua string so it will not be garbage collected.
     * 
     * \param string the lua string to pin.
     */
    extern void pinString(const char *string);
    
    /**
     * Unpins a lua string so it can be garbage collected.
     * 
     * \param string the lua string to unpin
     */
    extern void unpinString(const char *string);
}