#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RuaConstants
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
    // Whitespace
    if (isspace(*Idx)) {
      Idx++;
      continue;
    }

    // Ident / Keyword
    if (isalpha((unsigned char)*Idx) || *Idx == '_') {
      int IdentLength = 1;
      Idx++;
      while (isalnum((unsigned char)*Idx) || *Idx == '_') {
        IdentLength++;
        Idx++;
      }

      bool IsKeyword = false;
      for (uint Index = 0; Index < sizeof(RuaKeywords) / sizeof(const char *);
           Index++) {
        if (strncmp(RuaKeywords[Index], Idx - IdentLength, IdentLength) == 0) {
          IsKeyword = true;
          break;
        }
      }

      Token->Type = IsKeyword ? RUA_TOKEN_KEYWORD : RUA_TOKEN_IDENT;
      Token->Value.String = Idx - IdentLength;
      Token->Value.StringLength = IdentLength;
      Token = RuaNewToken(State);
      continue;

      // Number
    } else if (isdigit((unsigned char)*Idx)) {
      int NumberLength = 1;
      Idx++;
      while (isdigit((unsigned char)*Idx)) {
        NumberLength++;
        Idx++;
      }

      Token->Type = RUA_TOKEN_NUMBER;
      Token->Value.Number = atof(Idx - NumberLength);
      Token = RuaNewToken(State);
      continue;

      // Punct
    } else if (*Idx == '(' || *Idx == ')' || *Idx == '{' || *Idx == '}') {
      Token->Type = *Idx == '('   ? RUA_TOKEN_LPAREN
                    : *Idx == ')' ? RUA_TOKEN_RPAREN
                    : *Idx == '{' ? RUA_TOKEN_LBRACE
                                  : RUA_TOKEN_RBRACE;
      Token->Value.String = Idx;
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
      Token->Value.String = Idx - StringLength - 1;
      Token->Value.StringLength = StringLength;
      Token = RuaNewToken(State);
      continue;

      // Operator
    } else if (*Idx == '+' || *Idx == '-' || *Idx == '*' || *Idx == '\\') {
      Token->Type = RUA_TOKEN_OPERATOR;
      Token->Value.String = Idx;
      Token = RuaNewToken(State);
      Idx++;
      continue;

      // Equal
    } else if (*Idx == '=') {
      Token->Type = RUA_TOKEN_EQUAL;
      Token->Value.String = Idx;
      Token = RuaNewToken(State);
      Idx++;
      continue;
    }
    Idx++;
  }

  return RUA_SUCCESSFUL;
}
