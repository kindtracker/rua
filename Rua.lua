--[[
  Rua, single-file Lua implementation built in Lua.
  Copyright (C) 2026 Kindtracker

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local Rua = {}

local _

local BaseIdent = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local BasePunct = "(){}[];,:."
local BaseDigits = "0123456789"
local BaseOperators = "!=<>~&|+-*/^%#"
local BaseEscape = ""

local BaseKeywords = {
  "and",
  "break",
  "do",
  "else",
  "elseif",
  "end",
  "for",
  "function",
  "goto",
  "if",
  "in",
  "local",
  "not",
  "or",
  "repeat",
  "return",
  "then",
  "until",
  "while",
}

local ExpressionPrecedence = {
  ["or"] = 1,
  ["and"] = 2,

  ["=="] = 3,
  ["~="] = 3,
  ["<"] = 3,
  [">"] = 3,
  ["<="] = 3,
  [">="] = 3,

  ["|"] = 4,
  ["~"] = 5,
  ["&"] = 6,

  ["<<"] = 7,
  [">>"] = 7,

  [".."] = 8,

  ["+"] = 9,
  ["-"] = 9,

  ["*"] = 10,
  ["/"] = 10,
  ["//"] = 10,
  ["%"] = 10,

  ["^"] = 11,
}

local WhiteSpace = "\n\t\r "

local Ansi = {
  Reset = "\27[0m",
  Yellow = "\27[33m",
  Red = "\27[31m",
}

local function StringHasLetter(String, Letter)
  for Character in String:gmatch(".") do
    if Character == Letter then
      return true
    end
  end

  return false
end

local function TableHasString(Table, StringToSearch)
  for _, String in ipairs(Table) do
    if String == StringToSearch then
      return true
    end
  end

  return false
end

local function PrintTable(Table, Level)
  Level = Level or 0

  io.write(string.rep("  ", Level) .. "{\n")
  for Key, Value in pairs(Table) do
    if type(Value) == "table" then
      io.write(string.rep("  ", Level + 1) .. string.format("[%q] = {", Key))
      PrintTable(Value, Level + 1)
    else
      io.write(string.rep("  ", Level + 1) .. string.format("[%q] = %q", Key, Value))
    end
    io.write(",\n")
  end

  io.write(string.rep("  ", Level) .. "}")
end

local function GetLine(Content, Line)
  local CurrentLine = 1

  for TextLine in Content:gmatch("[^\r\n]*\r?\n?") do
    if TextLine == "" and CurrentLine > Line then
      break
    end

    if CurrentLine == Line then
      return TextLine:gsub("[\r\n]+$", "")
    end

    CurrentLine = CurrentLine + 1
  end

  return ""
end

local function GetWordStartAndFinish(Line, Row)
  local Start = Row
  local Finish = Row

  while Start > 1 and Line:sub(Start - 1, Start - 1):match("[%w_]") do
    Start = Start - 1
  end

  while Finish <= #Line and Line:sub(Finish, Finish):match("[%w_]") do
    Finish = Finish + 1
  end

  return Start, Finish
end

local function HighlightWord(Line, Row)
  local Start, Finish = GetWordStartAndFinish(Line, Row)
  return Line:sub(1, Start - 1) .. Ansi.Red .. Line:sub(Start, Finish - 1) .. Ansi.Reset .. Line:sub(Finish)
end

function Rua.new()
  return {
    FileName = "",
    FileContent = "",
    FileIndex = 0,
    TokenCharacter = "",
    Tokens = {},
    Ast = {},
    TokenIndex = 0,
    CurrentToken = {},
    Line = 1,
    Row = 1,
    Stop = false,
    Ir = { Program = {}, LabelCount = 0, Registers = {} },
  }
end

function Rua:Run(State, FileName)
  State.FileName = FileName
  State.FileContent = io.open(FileName, "r"):read("*a")

  Rua:Tokenize(State)
  PrintTable(State.Tokens)
  io.write("\n")

  Rua:Parse(State)
  PrintTable(State.Ast)
  io.write("\n")

  Rua:GenerateIr(State)
  PrintTable(State.Ir.Program)
  io.write("\n")
end

local Logger = {}

function Logger:Error(State, ...)
  local SourceLine = GetLine(State.FileContent, State.Line)
  local HighlightedWord = HighlightWord(SourceLine, State.Row)

  local WordStart, WordFinish = GetWordStartAndFinish(SourceLine, State.Row)
  local WordLength = WordFinish - WordStart

  io.write(
    string.format(
      "%s:%d:%d: %sError:%s %s\n %s\n%s%s^%s%s\n",
      State.FileName,
      State.Line,
      State.Row,
      Ansi.Red,
      Ansi.Reset,
      string.format(...),
      HighlightedWord,
      string.rep(" ", WordStart),
      Ansi.Red,
      string.rep("~", WordLength - 1),
      Ansi.Reset
    )
  )

  State.Stop = true
end

local Tokenizer = {}

function Tokenizer:Advance(State)
  local Character = State.TokenCharacter

  State.FileIndex = State.FileIndex + 1

  if Character == "\n" then
    State.Line = State.Line + 1
    State.Row = 1
  else
    State.Row = State.Row + 1
  end

  State.TokenCharacter = State.FileContent:sub(State.FileIndex, State.FileIndex)

  return Character
end

function Tokenizer:Initialize(State)
  State.FileIndex = 0
  State.Line = 1
  State.Row = 1
  State.TokenCharacter = State.FileContent:sub(1, 1)
end

function Tokenizer:AddToken(State, Kind, Value)
  table.insert(State.Tokens, { Kind = Kind, Value = Value, Line = State.Line, Row = State.Row })
end

function Rua:Tokenize(State)
  Tokenizer:Initialize(State)

  while true do
    if State.Stop then
      break
    end

    if StringHasLetter(BaseIdent, State.TokenCharacter) then
      local StartIndex = State.FileIndex
      local StartRow = State.Row

      while StringHasLetter(BaseIdent, State.TokenCharacter) do
        Tokenizer:Advance(State)
      end
      local EndRow = State.Row

      local Ident = State.FileContent:sub(StartIndex, State.FileIndex - 1)
      local IsKeyword = TableHasString(BaseKeywords, Ident)

      State.Row = StartRow
      Tokenizer:AddToken(State, IsKeyword and "Keyword" or "Ident", Ident)
      State.Row = EndRow
    elseif StringHasLetter(BasePunct, State.TokenCharacter) then
      local Punct = Tokenizer:Advance(State)

      State.Row = State.Row - 1
      Tokenizer:AddToken(State, "Punct", Punct)
      State.Row = State.Row + 1
    elseif StringHasLetter(BaseOperators, State.TokenCharacter) then
      local Operator = Tokenizer:Advance(State)
      local IsComment = false
      local IsMultipleLineComment = false

      if Operator == "-" then
        if State.TokenCharacter == "-" then
          IsComment = true
          Tokenizer:Advance(State)
          if State.TokenCharacter == "[" then
            Tokenizer:Advance(State)
            if State.TokenCharacter == "[" then
              IsMultipleLineComment = true
            end
          end

          while true do
            Tokenizer:Advance(State)
            if IsMultipleLineComment then
              if State.TokenCharacter == "]" then
                Tokenizer:Advance(State)
                if State.TokenCharacter == "]" then
                  Tokenizer:Advance(State)
                  break
                end
              end
            elseif State.TokenCharacter == "\n" then
              break
            end
          end
        end
      elseif Operator == "=" or Operator == "~" or Operator == ">" or Operator == "<" or Operator == "|" then
        if State.TokenCharacter == "=" then
          Operator = Operator .. "="
          Tokenizer:Advance(State)
        elseif State.TokenCharacter == ">" or Operator.TokenCharacter == "<" then
          Operator = Operator .. "="
          Tokenizer:Advance(State)
        end
      elseif Operator == "." then
        if State.TokenCharacter == "." then
          Operator = ".."
          Tokenizer:Advance(State)
        end
      elseif Operator == "/" then
        if State.TokenCharacter == "/" then
          Operator = "//"
          Tokenizer:Advance(State)
        end
      end

      if not IsComment then
        Tokenizer:AddToken(State, "Operator", Operator)
      end
    elseif StringHasLetter(BaseDigits, State.TokenCharacter) then
      local StartIndex = State.FileIndex

      while StringHasLetter(BaseDigits, State.TokenCharacter) do
        Tokenizer:Advance(State)
      end

      local Number = tonumber(State.FileContent:sub(StartIndex, State.FileIndex - 1))
      Tokenizer:AddToken(State, "Number", Number)
    elseif State.TokenCharacter == '"' or State.TokenCharacter == "'" then
      Tokenizer:Advance(State)
      local StartIndex = State.FileIndex

      while State.TokenCharacter ~= '"' and State.TokenCharacter ~= "'" do
        local Character = Tokenizer:Advance(State)
        if Character == "\\" then
          Tokenizer:Advance(State)
        end
      end
      Tokenizer:Advance(State)

      Tokenizer:AddToken(State, "String", State.FileContent:sub(StartIndex, State.FileIndex - 2))
    elseif StringHasLetter(WhiteSpace, State.TokenCharacter) then
      Tokenizer:Advance(State)
    else
      if State.FileIndex > #State.FileContent then
      else
        Logger:Error(State, "Unexpected character: '%s'", State.TokenCharacter)
      end
      break
    end
  end
end

local Parser = {}

function Parser:Advance(State, Step)
  Step = Step or 1

  local PreviousToken = State.CurrentToken
  State.TokenIndex = State.TokenIndex + Step
  State.CurrentToken = State.Tokens[State.TokenIndex]
  if State.CurrentToken then
    State.Line = State.CurrentToken.Line
    State.Row = State.CurrentToken.Row
  end
end

function Parser:Initalize(State)
  State.Stop = false
  State.Ast = {}
  State.TokenIndex = 0
  Parser:Advance(State)
end

function Parser:Expect(State, ...)
  local Arguments = table.pack(...)

  if State.CurrentToken == nil then
    Logger:Error(State, "Unexpected end of file")
    State.Stop = true
    return nil, nil
  end

  local AllTokenKinds = {
    "Ident",
    "Punct",
    "Number",
    "Operator",
    "String",
    "Keyword",
  }

  if TableHasString(AllTokenKinds, Arguments[1]) then
    if TableHasString(Arguments, State.CurrentToken.Kind) then
      local Kind = State.CurrentToken.Kind
      local Value = State.CurrentToken.Value

      Parser:Advance(State)

      return Kind, Value
    end

    local HumanExpectedTokens = ""

    for Index, Value in ipairs(Arguments) do
      if Index > 1 then
        HumanExpectedTokens = HumanExpectedTokens .. " or "
      end

      HumanExpectedTokens = HumanExpectedTokens .. string.format("'%s'", Value)
    end

    Logger:Error(State, "Expected %s but got '%s'", HumanExpectedTokens, State.CurrentToken.Kind)

    State.Stop = true
    return nil, nil
  end

  for Index = 1, Arguments.n do
    if State.CurrentToken.Value == Arguments[Index] then
      local Kind = State.CurrentToken.Kind
      local Value = State.CurrentToken.Value

      Parser:Advance(State)

      return Kind, Value
    end
  end

  local HumanExpectedTokens = ""

  for Index = 1, Arguments.n do
    if Index > 1 then
      HumanExpectedTokens = HumanExpectedTokens .. " or "
    end

    HumanExpectedTokens = HumanExpectedTokens .. string.format("'%s'", Arguments[Index])
  end

  Logger:Error(State, "Expected %s but got '%s'", HumanExpectedTokens, State.CurrentToken.Value)

  State.Stop = true
  return nil, nil
end

function Parser:GetExpressionPrecedence(State)
  if State.CurrentToken == nil then
    return nil
  end

  return ExpressionPrecedence[State.CurrentToken.Value]
end

function Parser:ParsePrimaryExpression(State)
  if State.CurrentToken == nil then
    return nil
  end

  local Token = State.CurrentToken

  if Token.Kind == "Ident" then
    Parser:Advance(State)

    return {
      Type = "Identifier",
      Value = Token.Value,
    }
  end

  if Token.Kind == "Number" then
    Parser:Advance(State)

    return {
      Type = "Number",
      Value = Token.Value,
    }
  end

  if Token.Kind == "String" then
    Parser:Advance(State)

    return {
      Type = "String",
      Value = Token.Value,
    }
  end

  if Token.Value == "true" or Token.Value == "false" then
    Parser:Advance(State)

    return {
      Type = "Boolean",
      Value = Token.Value == "true",
    }
  end

  if Token.Value == "nil" then
    Parser:Advance(State)

    return {
      Type = "Nil",
      Value = nil,
    }
  end

  if Token.Value == "(" then
    Parser:Advance(State)

    local Expression = Parser:ParseExpression(State)

    local Kind = Parser:Expect(State, ")")
    if Kind == nil then
      return nil
    end

    return Expression
  end

  return nil
end

function Parser:ParseExpression(State, MinimumPrecedence)
  MinimumPrecedence = MinimumPrecedence or 0

  local Left = Parser:ParsePrimaryExpression(State)

  if Left == nil then
    return nil
  end

  while State.CurrentToken ~= nil do
    local Operator = State.CurrentToken.Value
    local Precedence = Parser:GetExpressionPrecedence(State)

    if Precedence == nil or Precedence < MinimumPrecedence then
      break
    end

    Parser:Advance(State)

    local Right = Parser:ParseExpression(State, Precedence + 1)

    if Right == nil then
      State.Stop = true
      return nil
    end

    Left = {
      Type = "BinaryExpression",
      Operator = Operator,
      Left = Left,
      Right = Right,
    }
  end

  return Left
end

function Parser:ParseArgumentList(State)
  local ArgumentList = {}

  local Argument
  while true do
    ArgumentNode = Parser:ParseExpression(State)
    table.insert(ArgumentList, ArgumentNode)

    if State.CurrentToken.Value ~= "," then
      break
    else
      Parser:Advance(State)
    end
  end

  return ArgumentList
end

function Parser:ParseBlock(State, ...)
  local Body = {}

  while true do
    if State.Stop then
      break
    elseif State.CurrentToken.Kind == "Keyword" and TableHasString({ ... }, State.CurrentToken.Value) then
      break
    end

    local Statement = Parser:ParseStatement(State)

    if Statement ~= nil then
      table.insert(Body, Statement)
    end
  end
  Parser:Expect(State, ...)

  return Body
end

function Parser:ParseFunctionCall(State, Statement)
  Statement.Type = "FunctionCall"
  Statement.Name = State.CurrentToken.Value
  Parser:Advance(State, 2)
  Statement.Arguments = Parser:ParseArgumentList(State)

  Kind, Value = Parser:Expect(State, ")")
  if Kind == nil then
    return
  end
end

function Parser:ParseVariableAssign(State, Statement)
  Statement.Type = "VariableAssign"
  Statement.Name = State.CurrentToken.Value
  Parser:Advance(State, 2)
  Statement.Value = Parser:ParseExpression(State)
end

function Parser:ParseFunction(State, Statement)
  Statement.Type = "Function"
  Statement.Name = State.CurrentToken.Value
  Parser:Advance(State)
  Statement.Arguments = Parser:ParseArgumentList(State)
  Statement.Body = Parser:ParseBlock(State)
end

function Parser:ParseReturn(State, Statement)
  Statement.Type = "Return"
  Statement.Value = Parser:ParseExpression(State)
end

function Parser:ParseIf(State, Statement)
  Statement.Type = "If"
  Statement.Condition = Parser:ParseExpression(State)
  Parser:Advance(State)
  Statement.Body = Parser:ParseBlock(State, "end", "elseif", "else")
  Parser:Advance(State, -1)
  if State.CurrentToken.Value == "else" then
    Parser:Advance(State)
    Statement.Else = Parser:ParseBlock(State, "end")
  elseif State.CurrentToken.Value == "elseif" then
    Parser:Advance(State)
    Statement.ElseIf = {}
    Statement.Elseif = Parser:ParseIf(State, Statement.ElseIf, "end", "elseif", "else")
  end
end

function Parser:ParseStatement(State, IsLocal)
  local Statement = { Local = IsLocal or false }

  local Kind, Value = Parser:Expect(State, "Ident", "Keyword")
  if Kind == nil then
    return
  end

  if Kind == "Ident" then
    Kind, Value = Parser:Expect(State, "Punct", "Operator")
    if Kind == nil then
      return
    end

    if Value == "(" then
      Parser:Advance(State, -2)
      Parser:ParseFunctionCall(State, Statement)
    elseif Value == "=" then
      Parser:Advance(State, -2)
      Parser:ParseVariableAssign(State, Statement)
    else
      Logger:Error(State, "Expected '(' or '=' but got '%s'", State.CurrentToken.Value)
    end
  elseif Kind == "Keyword" then
    if Value == "local" then
      return Parser:ParseStatement(State, true)
    elseif Value == "function" then
      Parser:ParseFunction(State, Statement)
    elseif Value == "return" then
      Parser:ParseReturn(State, Statement)
    elseif Value == "if" then
      Parser:ParseIf(State, Statement)
    else
      Logger:Error(State, "Unhandled keyword: %s", Value)
    end
  else
    Logger:Error(State, "Unhandled token kind: %s", Value)
  end

  return Statement
end

function Rua:Parse(State)
  Parser:Initalize(State)

  while State.CurrentToken ~= nil do
    if State.Stop then
      break
    end

    local Statement = Parser:ParseStatement(State)

    if Statement ~= nil then
      table.insert(State.Ast, Statement)
    end
  end
end

local IrGenerator = {}

function IrGenerator:NewIr(State)
  table.insert(State.Ir.Program, State.CurrentIr)
  State.CurrentIr = {
    Arguments = {},
  }
end

function IrGenerator:NewBlankIr(State)
  State.CurrentIr = {
    Arguments = {},
  }
end

function IrGenerator:NewLabel(State)
  State.Ir.LabelCount = State.Ir.LabelCount + 1
  return State.Ir.LabelCount
end

function IrGenerator:GenerateBlock(State, Body)
  for _, Ast in ipairs(Body) do
    IrGenerator:GenerateIr(State, Ast, 0)
  end
end

function IrGenerator:ConvertStringToIr(State, String)
  local ResultRegister = IrGenerator:GenerateIr(State, {
    Type = "String",
    Value = String,
  })

  return ResultRegister
end

function IrGenerator:AllocateRegister(State)
  for Register, Used in pairs(State.Ir.Registers) do
    if not Used then
      IrGenerator:MarkUsed(State, Register)
      return Register
    end
  end

  Logger:Error("Failed to allocate a register")
  return nil
end

function IrGenerator:MarkUsed(State, Register)
  State.Ir.Registers[Register] = true
end

function IrGenerator:MarkNotUsed(State, Register)
  State.Ir.Registers[Register] = false
end

function IrGenerator:GenerateIr(State, Ast)
  State.CurrentIr = { Arguments = {} }

  if Ast.Type == "FunctionCall" then
    for _, Argument in pairs(Ast.Arguments) do
      IrGenerator:GenerateIr(State, Argument, 0)
    end

    local FunctionNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Name)
    local FunctionRegister = IrGenerator:AllocateRegister(State)

    State.CurrentIr.Type = "GetFunction"
    State.CurrentIr.Arguments = {
      [1] = FunctionNameRegister,
      [2] = FunctionRegister,
    }
    IrGenerator:MarkNotUsed(State, FunctionNameRegister)
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "CallFromRegister"
    State.CurrentIr.Arguments = {
      [1] = FunctionRegister,
    }
    IrGenerator:MarkNotUsed(State, FunctionRegister)
    IrGenerator:NewIr(State)
  elseif Ast.Type == "Number" then
    local ResultRegister = IrGenerator:AllocateRegister(State)
    State.CurrentIr.Type = "LoadNumber"
    State.CurrentIr.Arguments = {
      [1] = Ast.Value,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)
  elseif Ast.Type == "String" then
    local ResultRegister = IrGenerator:AllocateRegister(State)
    State.CurrentIr.Type = "LoadString"
    State.CurrentIr.Arguments = {
      [1] = Ast.Value,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)
  elseif Ast.Type == "Identifier" then
    local VariableNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Value)
    local VariableRegister = IrGenerator:AllocateRegister(State)

    State.CurrentIr.Type = "GetVariable"
    State.CurrentIr.Arguments = {
      [1] = VariableNameRegister,
      [2] = VariableRegister,
    }
    IrGenerator:MarkNotUsed(State, VariableNameRegister)
    IrGenerator:NewIr(State)
  elseif Ast.Type == "VariableAssign" then
    local VariableNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Name)
    local ResultRegister = IrGenerator:GenerateIr(State, Ast.Value)

    State.CurrentIr.Type = (Ast.Local and "Local" or "Global") .. "VariableAssign"
    State.CurrentIr.Arguments = {
      [1] = VariableNameRegister,
      [2] = ResultRegister,
    }
    IrGenerator:MarkNotUsed(State, VariableNameRegister)
    IrGenerator:MarkNotUsed(State, ResultRegister)
    IrGenerator:NewIr(State)
  elseif Ast.Type == "Return" then
    local ReturnRegister = IrGenerator:GenerateIr(State, Ast.Value)

    State.CurrentIr.Type = "Push"
    State.CurrentIr.Arguments = {
      [1] = ReturnRegister,
    }
    IrGenerator:MarkNotUsed(State, ReturnRegister)
    IrGenerator:NewIr(State)
  elseif Ast.Type == "If" then
    local EndLabel = IrGenerator:NewLabel(State)

    local ResultRegister = IrGenerator:GenerateIr(State, Ast.Condition)

    State.CurrentIr.Type = "Test"
    State.CurrentIr.Arguments = {
      [1] = ResultRegister,
    }
    IrGenerator:MarkNotUsed(State, ResultRegister)
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Jump"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)

    IrGenerator:GenerateBlock(State, Ast.Body)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)
  end

  State.CurrentIr = { Arguments = {} }
end

function Rua:GenerateIr(State)
  for _, Ast in pairs(State.Ast) do
    IrGenerator:GenerateIr(State, Ast)
  end
end

Rua.Logger = Logger
Rua.Tokenizer = Tokenizer
Rua.Parser = Parser

-- File -> Tokenizer -> Tokens -> Parser -> Ast ->
-- Ir generator -> Ir -> Bytecode generator -> Bytecode ->
-- Stack VM

-- TODO: Make Ir generator, code generator, and VM (stack-based)
-- TODO: Handle strings properly (handle escape)
-- TODO: Handle hex and binary numbers

return Rua
