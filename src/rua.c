#include <cjson/cJSON.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RuaConstants
#include "rua.h"

RuaState RuaNewState() {
  RuaState State = {0};
  return State;
}

RuaResult RuaLoadString(RuaState *State, const char *LuaCode) {
  RuaTokenizeLua(State, LuaCode);
  RuaParseLua(State);
  return RUA_SUCCESSFUL;
}

cJSON *RuaJSONString(const char *String, int Length) {
  char *Buffer = malloc((size_t)Length + 1);

  memcpy(Buffer, String, (size_t)Length);
  Buffer[Length] = '\0';

  cJSON *Json = cJSON_CreateString(Buffer);

  free(Buffer);
  return Json;
}

const char *RuaValueTypeString(RuaValueType Type) {
  for (size_t i = 0;
       i < sizeof(RuaValueTypeToString) / sizeof(RuaValueTypeToString[0]);
       i++) {
    if (RuaValueTypeToString[i].Key == (int)Type) {
      return RuaValueTypeToString[i].Value;
    }
  }

  return "Unknown";
}

const char *RuaTokenTypeString(RuaTokenType Type) {
  for (size_t i = 0;
       i < sizeof(RuaTokenTypeToString) / sizeof(RuaTokenTypeToString[0]);
       i++) {
    if (RuaTokenTypeToString[i].Key == (int)Type) {
      return RuaTokenTypeToString[i].Value;
    }
  }

  return "Unknown";
}

const char *RuaASTTypeString(RuaASTType Type) {
  for (size_t i = 0;
       i < sizeof(RuaASTTypeToString) / sizeof(RuaASTTypeToString[0]); i++) {
    if (RuaASTTypeToString[i].Key == (int)Type) {
      return RuaASTTypeToString[i].Value;
    }
  }

  return "Unknown";
}

RuaResult RuaPrintTokens(RuaState *State) {
  cJSON *Json = cJSON_CreateArray();

  for (int i = 0; i < State->TokenCount; i++) {
    RuaToken *Token = &State->Tokens[i];
    cJSON *TokenJson = cJSON_CreateObject();
    cJSON_AddStringToObject(TokenJson, "Type", RuaTokenTypeString(Token->Type));
    if (Token->Type == RUA_TOKEN_IDENT || Token->Type == RUA_TOKEN_KEYWORD ||
        Token->Type == RUA_TOKEN_STRING) {
      cJSON_AddItemToObject(
          TokenJson, "Value",
          RuaJSONString(Token->Value.String, Token->Value.StringLength));
    } else if (Token->Type == RUA_TOKEN_NUMBER) {
      cJSON_AddNumberToObject(TokenJson, "Value", Token->Value.Number);
    }

    cJSON_AddItemToArray(Json, TokenJson);
  }

  char *String = cJSON_Print(Json);
  printf("%s\n", String);

  free(String);
  cJSON_Delete(Json);
  return RUA_SUCCESSFUL;
}

void RuaPrintASTNode(cJSON *Json, RuaASTNode *Node) {
  cJSON *NodeJson = cJSON_CreateObject();

  cJSON_AddStringToObject(NodeJson, "Type", RuaASTTypeString(Node->Type));

  if (Node->Name) {
    cJSON_AddItemToObject(NodeJson, "Name",
                          RuaJSONString(Node->Name, Node->NameLength));
  }

  cJSON_AddBoolToObject(NodeJson, "Local", Node->IsLocal);
  cJSON_AddNumberToObject(NodeJson, "Arguments", Node->ArgumentCount);
  cJSON_AddNumberToObject(NodeJson, "Parameters", Node->ParameterCount);

  if (Node->ChildCount > 0) {
    cJSON *Children = cJSON_CreateArray();

    for (int i = 0; i < Node->ChildCount; i++) {
      RuaPrintASTNode(Children, Node->Children[i]);
    }

    cJSON_AddItemToObject(NodeJson, "Children", Children);
  }

  cJSON_AddItemToArray(Json, NodeJson);
}

RuaResult RuaPrintAST(RuaState *State) {
  cJSON *Json = cJSON_CreateArray();

  for (int i = 0; i < State->AST.ChildCount; i++) {
    RuaPrintASTNode(Json, State->AST.Children[i]);
  }

  char *String = cJSON_Print(Json);
  printf("%s\n", String);

  free(String);
  cJSON_Delete(Json);
  return RUA_SUCCESSFUL;
}
