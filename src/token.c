#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>

#include "rua.h"

RuaToken *RuaNewToken(RuaState *State) {
  State->TokenCount++;

  State->Tokens = realloc(State->Tokens, State->TokenCount * sizeof(RuaToken));

  return &State->Tokens[State->TokenCount - 1];
}

RuaResult RuaTokenizeLua(RuaState *State, const char *LuaCode) {
  State->Tokens = malloc(sizeof(RuaToken));
  State->TokenCount = 0;

  RuaNewToken(State);
  RuaToken *Token = State->Tokens;

  const char *Idx = LuaCode;
  while (*Idx) {
    // Ident
    if (isalpha((unsigned char)*Idx) || *Idx == '_') {
      int IdentLength = 1;
      Idx++;
      while (isalnum((unsigned char)*Idx) || *Idx == '_') {
        IdentLength++;
        Idx++;
      }

      printf("Token %d\n", State->TokenCount);
      Token->Type = RUA_TOKEN_IDENT;
      Token->String = Idx - IdentLength;
      Token->StringLength = IdentLength;
      Token = RuaNewToken(State);
      continue;

      // Punct
    } else if (*Idx == '(' || *Idx == ')' || *Idx == '{' || *Idx == '}') {
      Token->Type = *Idx == '('   ? RUA_TOKEN_LPAREN
                    : *Idx == ')' ? RUA_TOKEN_RPAREN
                    : *Idx == '{' ? RUA_TOKEN_LBRACE
                                  : RUA_TOKEN_RBRACE;
      Token->String = Idx;
      Token = RuaNewToken(State);
      Idx++;
      continue;

      // String
    } else if (*Idx == '"') {
      int StringLength = 0;
      Idx++;
      while (*Idx != '"') {
        StringLength++;
        Idx++;
      }
      Idx++;

      Token->Type = RUA_TOKEN_STRING;
      Token->String = Idx - StringLength - 1;
      Token->StringLength = StringLength;
      Token = RuaNewToken(State);
      continue;
    }
    Idx++;
  }

  return RUA_SUCCESSFUL;
}
