#include <stdio.h>
#include <stdlib.h>

#include "rua.h"

RuaToken *RuaNextToken(RuaState *State) {
  State->TokenIdx++;
  return &State->Tokens[State->TokenIdx];
}

RuaResult RuaParseLua(RuaState *State) {
  State->TokenIdx = 0;
  RuaToken *Token = State->Tokens;

  while (Token->Type != RUA_TOKEN_EOF) {
    printf("%d\n", Token->Type);
    Token = RuaNextToken(State);
  }

  return RUA_SUCCESSFUL;
}
