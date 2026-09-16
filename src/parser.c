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
    }
    Idx++;
  }

  return RUA_SUCCESSFUL;
}
