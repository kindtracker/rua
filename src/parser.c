#include <stdio.h>
#include <stdlib.h>

#include "rua.h"

RuaToken *RuaNextToken(RuaState *State) {
  State->TokenIdx++;
  return &State->Tokens[State->TokenIdx];
}

RuaASTExpr *RuaParseExpr(RuaState *State) {
  RuaASTExpr *Expr = malloc(sizeof(RuaASTExpr));
  if (State->Token->Type == RUA_TOKEN_STRING) {
    Expr->Value.Type = RUA_VALUE_STRING;
    Expr->Value.String = State->Token->String;
    Expr->Value.StringLength = State->Token->StringLength;
  } else if (State->Token->Type == RUA_TOKEN_NUMBER) {
    Expr->Value.Type = RUA_VALUE_NUMBER;
    Expr->Value.Number = State->Token->Number;
  } else if (State->Token->Type == RUA_TOKEN_IDENT) {
    Expr->Value.Type = RUA_VALUE_IDENT;
    Expr->Value.String = State->Token->String;
    Expr->Value.StringLength = State->Token->StringLength;
  }

  return Expr;
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
    Node->Arguments[Node->ArgumentCount] = *RuaParseExpr(State);
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
    printf("%d\n", Node->Type);
  }
  return Node;
}

RuaResult RuaParseLua(RuaState *State) {
  State->TokenIdx = -1;
  State->Token = State->Tokens;

  while (State->Token->Type != RUA_TOKEN_EOF) {
    RuaASTNode *Node = RuaParseStatemenet(State);
    Node = Node;
  }

  return RUA_SUCCESSFUL;
}
