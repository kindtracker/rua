#include "rua.h"

RuaState RuaNewState() {
  RuaState State = {0};
  return State;
}

RuaResult RuaParseLua(RuaState *State, const char *LuaCode) {
  return RUA_SUCCESSFUL;
}

RuaResult RuaLoadString(RuaState *State, const char *LuaCode) {
  RuaTokenizeLua(State, LuaCode);
  return RUA_SUCCESSFUL;
}
