#pragma once

typedef enum { RUA_SUCCESSFUL = 0, RUA_FAIL = 101 } RuaResult;

RuaResult RuaTokenizeLua(const char *LuaCode);
RuaResult RuaParseLua(const char *LuaCode);
RuaResult RuaLoadString(const char *LuaCode);
