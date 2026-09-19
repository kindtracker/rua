#pragma once

typedef enum { RUA_SUCCESSFUL = 0, RUA_FAIL = 101 } RuaResult;

typedef struct {
  int Key;
  const char *Value;
} RuaMapEntry;

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

typedef enum {
  RUA_AST_CALL,
  RUA_AST_VAR_DECL,
  RUA_AST_FUNCTION,
  RUA_AST_BLOCK
} RuaASTType;

typedef struct RuaASTNode {
  RuaASTType Type;
  RuaASTExpr Value;
  const char *Name;
  int NameLength;

  struct RuaASTNode **Children;
  int ChildCount;

  RuaASTExpr Arguments[32];
  int ArgumentCount;
  const char *Parameters[32];
  int ParameterCount;
  bool IsLocal;
} RuaASTNode;

typedef struct {
  const char *LuaCode;

  RuaToken *Tokens;
  int TokenCount;
  RuaToken *Token;
  int TokenIdx;

  RuaASTNode AST;
} RuaState;

#ifdef RuaXTypeToString
RuaMapEntry RuaTokenTypeToString[] = {
    {RUA_TOKEN_EOF, "<eof>"},         {RUA_TOKEN_IDENT, "Ident"},
    {RUA_TOKEN_NUMBER, "Number"},     {RUA_TOKEN_STRING, "String"},
    {RUA_TOKEN_LPAREN, "LParen"},     {RUA_TOKEN_RPAREN, "RParen"},
    {RUA_TOKEN_LBRACE, "LBrace"},     {RUA_TOKEN_RBRACE, "RBrace"},
    {RUA_TOKEN_LBRACKET, "LBRacket"}, {RUA_TOKEN_RBRACKET, "RBRacket"},
    {RUA_TOKEN_OPERATOR, "Operator"}, {RUA_TOKEN_EQUAL, "Equal"},
    {RUA_TOKEN_KEYWORD, "Keyword"},   {RUA_TOKEN_NONE, "<none>"}};

RuaMapEntry RuaValueTypeToString[] = {{RUA_VALUE_IDENT, "Ident"},
                                      {RUA_VALUE_STRING, "String"},
                                      {RUA_VALUE_NUMBER, "Number"}};

RuaMapEntry RuaASTTypeToString[] = {{RUA_AST_CALL, "Call"},
                                    {RUA_AST_VAR_DECL, "VarDecl"},
                                    {RUA_AST_FUNCTION, "Function"},
                                    {RUA_AST_BLOCK, "Block"}};
#endif

RuaState RuaNewState();
RuaResult RuaTokenizeLua(RuaState *State, const char *LuaCode);
RuaASTNode *RuaParseStatemenet(RuaState *State, bool Local);
RuaResult RuaParseLua(RuaState *State);
RuaResult RuaLoadString(RuaState *State, const char *LuaCode);
RuaResult RuaPrintTokens(RuaState *State);
RuaResult RuaPrintAST(RuaState *State);
