#pragma once

typedef enum { RUA_SUCCESSFUL = 0, RUA_FAIL = 101 } RuaResult;

typedef enum {
  RUA_VALUE_IDENT,
  RUA_VALUE_STRING,
  RUA_VALUE_NUMBER,
} RuaValueType;

typedef struct {
  RuaValueType Type;
  const char *String;
  int StringLength;
  double Number;
} RuaValue;

typedef enum {
  RUA_TOKEN_EOF,

  RUA_TOKEN_IDENT,
  RUA_TOKEN_NUMBER,
  RUA_TOKEN_STRING,

  RUA_TOKEN_LPAREN,   // (
  RUA_TOKEN_RPAREN,   // )
  RUA_TOKEN_LBRACE,   // {
  RUA_TOKEN_RBRACE,   // }
  RUA_TOKEN_LBRACKET, // [
  RUA_TOKEN_RBRACKET, // ]

  RUA_TOKEN_OPERATOR,
  RUA_TOKEN_EQUAL,
  RUA_TOKEN_KEYWORD,

  RUA_TOKEN_NONE
} RuaTokenType;

typedef struct {
  RuaTokenType Type;
  RuaValue Value;
} RuaToken;

typedef struct {
  RuaValue Value;
} RuaASTExpr;

typedef enum { RUA_AST_CALL, RUA_AST_VAR_DECL } RuaASTType;

typedef struct RuaASTNode {
  RuaASTType Type;

  RuaASTExpr Value;

  struct RuaASTNode **Children;
  int ChildCount;

  RuaASTExpr Arguments[32];
  int ArgumentCount;
} RuaASTNode;

typedef struct {
  const char *LuaCode;

  RuaToken *Tokens;
  int TokenCount;
  RuaToken *Token;
  int TokenIdx;

  RuaASTNode AST;
} RuaState;

RuaState RuaNewState();
RuaResult RuaTokenizeLua(RuaState *State, const char *LuaCode);
RuaResult RuaParseLua(RuaState *State);
RuaResult RuaLoadString(RuaState *State, const char *LuaCode);
