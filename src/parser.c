#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "rua.h"

RuaToken *RuaNextToken(RuaState *State) {
  State->TokenIdx++;
  return &State->Tokens[State->TokenIdx];
}

RuaASTExpr *RuaParseExpr(RuaState *State) {
  RuaASTExpr *Expr = malloc(sizeof(RuaASTExpr));
  if (State->Token->Type == RUA_TOKEN_STRING) {
    Expr->Value.Type = RUA_VALUE_STRING;
    Expr->Value.String = State->Token->Value.String;
    Expr->Value.StringLength = State->Token->Value.StringLength;
  } else if (State->Token->Type == RUA_TOKEN_NUMBER) {
    Expr->Value.Type = RUA_VALUE_NUMBER;
    Expr->Value.Number = State->Token->Value.Number;
  } else if (State->Token->Type == RUA_TOKEN_IDENT) {
    Expr->Value.Type = RUA_VALUE_IDENT;
    Expr->Value.String = State->Token->Value.String;
    Expr->Value.StringLength = State->Token->Value.StringLength;
  }

  return Expr;
}

void RuaParseCall(RuaState *State, RuaASTNode *Node) {
  Node->Type = RUA_AST_CALL;

  State->TokenIdx -= 2;
  State->Token = RuaNextToken(State);
  Node->Value.Value = State->Token->Value;

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

void RuaParseVarDecl(RuaState *State, RuaASTNode *Node) {
  Node->Type = RUA_AST_VAR_DECL;

  State->TokenIdx -= 2;
  State->Token = RuaNextToken(State);
  Node->Value.Value = State->Token->Value;

  State->TokenIdx += 1;
  State->Token = RuaNextToken(State);

  Node->Value = *RuaParseExpr(State);
  printf("b%f\n", Node->Value.Value.Number);
}

RuaASTNode *RuaParseBlock(RuaState *State) {
  RuaASTNode *Block = malloc(sizeof(RuaASTNode));

  Block->Type = RUA_AST_BLOCK;
  Block->Children = NULL;
  Block->ChildCount = 0;

  while (State->Token->Type != RUA_TOKEN_EOF) {
    if (State->Token->Type == RUA_TOKEN_KEYWORD &&
        (strcmp(State->Token->Value.String, "end") == 0 ||
         strcmp(State->Token->Value.String, "else") == 0 ||
         strcmp(State->Token->Value.String, "elseif") == 0)) {
      break;
    }

    RuaASTNode *Node = RuaParseStatemenet(State, false);

    Block->ChildCount++;
    Block->Children =
        realloc(Block->Children, Block->ChildCount * sizeof(RuaASTNode *));
    Block->Children[Block->ChildCount - 1] = Node;
  }

  return Block;
}

void RuaParseFunction(RuaState *State, RuaASTNode *Node) {
  Node->Type = RUA_AST_FUNCTION;
  Node->ParameterCount = 0;
  Node->Children = NULL;
  Node->ChildCount = 0;

  State->Token = RuaNextToken(State);

  Node->Name = State->Token->Value.String;
  Node->NameLength = State->Token->Value.StringLength;

  State->Token = RuaNextToken(State);
  if (State->Token->Type != RUA_TOKEN_LPAREN) {
    return;
  }
  State->Token = RuaNextToken(State);

  while (true) {
    Node->Arguments[Node->ArgumentCount] = *RuaParseExpr(State);
    printf("%s\n", Node->Arguments[Node->ArgumentCount].Value.String);

    Node->ArgumentCount++;

    State->Token = RuaNextToken(State);
    if (State->Token->Type == RUA_TOKEN_RPAREN) {
      break;
    }
  }
}

RuaASTNode *RuaParseStatemenet(RuaState *State, bool Local) {
  RuaASTNode *Node = malloc(sizeof(RuaASTNode));

  State->Token = RuaNextToken(State);
  if (State->Token->Type == RUA_TOKEN_KEYWORD) {
    if (strncmp(State->Token->Value.String, "local", 5) == 0) {
      return RuaParseStatemenet(State, true);
    } else if (strncmp(State->Token->Value.String, "function", 8) == 0) {
      RuaParseFunction(State, Node);
    }
  } else if (State->Token->Type == RUA_TOKEN_IDENT) {
    State->Token = RuaNextToken(State);
    if (State->Token->Type == RUA_TOKEN_LPAREN) {
      RuaParseCall(State, Node);
    } else if (State->Token->Type == RUA_TOKEN_EQUAL) {
      RuaParseVarDecl(State, Node);
    }
  }
  if (Local) {
    Node->IsLocal = true;
  }
  return Node;
}

RuaResult RuaParseLua(RuaState *State) {
  State->TokenIdx = -1;
  State->Token = State->Tokens;

  while (State->Token->Type != RUA_TOKEN_EOF) {
    RuaASTNode *Node = RuaParseStatemenet(State, false);
    Node = Node;
  }

  return RUA_SUCCESSFUL;
}
