#include <ctype.h>
#include <stdio.h>

#include "rua.h"

RuaResult RuaTokenizeLua(const char *LuaCode) {
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

      printf("%.*s\n", IdentLength, Idx - IdentLength);
      continue;
    } else if (*Idx == '(' || *Idx == ')' || *Idx == '{' || *Idx == '}') {
      printf("%c\n", *Idx);
      Idx++;
      continue;
    } else if (*Idx == '"') {
      int StringLength = 0;
      Idx++;
      while (*Idx != '"') {
        StringLength++;
        Idx++;
      }
      Idx++;

      printf("%.*s\n", StringLength, Idx - StringLength - 1);
      continue;
    }
    Idx++;
  }

  return RUA_SUCCESSFUL;
}
