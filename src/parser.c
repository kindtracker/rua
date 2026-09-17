#include <stdio.h>
#include <stdlib.h>

#include "rua.h"

RuaToken *RuaNextToken(RuaState *State) {
  State->TokenIdx++;
  return &State->Tokens[State->TokenIdx];
}

void RuaParseCall(RuaState *State, RuaASTNode *Node) {
  Node->Type = RUA_AST_CALL;

  State->TokenIdx -= 2;
  State->Token = RuaNextToken(State);
  Node->String = State->Token->String;
  Node->StringLength = State->Token->StringLength;

  State->TokenIdx += 1;
  State->Token = RuaNextToken(State);

  while (true) {
    if (State->Token->Type == RUA_TOKEN_STRING) {
      Node->Arguments[Node->ArgumentCount].Type = RUA_VALUE_STRING;
      Node->Arguments[Node->ArgumentCount].String = State->Token->String;
      Node->Arguments[Node->ArgumentCount].StringLength =
          State->Token->StringLength;
    } else if (State->Token->Type == RUA_TOKEN_NUMBER) {
      Node->Arguments[Node->ArgumentCount].Type = RUA_VALUE_NUMBER;
      Node->Arguments[Node->ArgumentCount].Number = State->Token->Number;
    }
    Node->ArgumentCount++;

    State->Token = RuaNextToken(State);
    if (State->Token->Type == RUA_TOKEN_RPAREN) {
      break;
    }
  }
}

RuaASTNode *RuaParseStatemenet(RuaState *State) {
  RuaASTNode *Node = malloc(sizeof(RuaASTNode));

  State->Token = RuaNextToken(State);
  if (State->Token->Type == RUA_TOKEN_IDENT) {
    State->Token = RuaNextToken(State);
    if (State->Token->Type == RUA_TOKEN_LPAREN) {
      RuaParseCall(State, Node);
    }
  }
  return Node;
}

RuaResult RuaParseLua(RuaState *State) {
  State->TokenIdx = -1;
  State->Token = State->Tokens;

  while (State->Token->Type != RUA_TOKEN_EOF) {
    RuaASTNode *Node = RuaParseStatemenet(State);
  }

  return RUA_SUCCESSFUL;
}
