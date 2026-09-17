#include "rua.h"

RuaState RuaNewState() {
  RuaState State = {0};
  return State;
}

RuaResult RuaLoadString(RuaState *State, const char *LuaCode) {
  RuaTokenizeLua(State, LuaCode);
  RuaParseLua(State);
  return RUA_SUCCESSFUL;
}
