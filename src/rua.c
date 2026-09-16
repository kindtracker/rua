#include "rua.h"

RuaResult RuaParseLua(const char *LuaCode) { return RUA_SUCCESSFUL; }

RuaResult RuaLoadString(const char *LuaCode) {
  RuaTokenizeLua(LuaCode);
  return RUA_SUCCESSFUL;
}
