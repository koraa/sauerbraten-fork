local ffi = require "ffi"

ffi.cdef [[
    //EXPORTH(void draw_text(const char *str, int left, int top, int r = 255, int g = 255, int b = 255, int a = 255, int cursor = -1, int maxwidth = -1));
    void draw_text(const char *str, int left, int top, int r, int g, int b, int a, int cursor, int maxwidth);

    void text_boundsp(const char *str, int *w, int *h, int maxwidth);
]]

return ffi.C