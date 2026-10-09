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
local BaseOperators = "=<>~&|+-*/^%#"
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
  Blue = "\27[38;2;100;200;255m",
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
    Ir = {
      Program = {},
      LabelCount = 0,
      Registers = {},
    },
    ShowFaultLine = true,
    Lua = { Program = "" },
    Runtime = {
      Registers = {},
      Variables = {},
      Functions = {},
      Stack = {},
    },
  }
end

function Rua:Run(State, FileName)
  State.FileName = FileName
  State.FileContent = io.open(FileName, "r"):read("*a")

  Rua:Tokenize(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    PrintTable(State.Tokens)
    io.write("\n")
  end

  Rua:Parse(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    PrintTable(State.Ast)
    io.write("\n")
  end

  State.ShowFaultLine = false

  Rua:GenerateIr(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    PrintTable(State.Ir.Program)
    io.write("\n")
  end

  Rua:GenerateLua(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    io.open("Dev.lua", "w"):write(State.Lua.Program)
  end
end

local Logger = {}

function Logger:Error(State, ...)
  local SourceLine = GetLine(State.FileContent, State.Line)
  local HighlightedWord = HighlightWord(SourceLine, State.Row)

  local WordStart, WordFinish = GetWordStartAndFinish(SourceLine, State.Row)
  local WordLength = WordFinish - WordStart

  local Format = "%sError:%s %s\n"
  if State.ShowFaultLine then
    Format = "%s:%d:%d: " .. Format
    Format = Format .. " %s\n%s%s^%s%s\n"
  else
    Format = "%s: " .. Format
  end

  if State.ShowFaultLine then
    io.write(
      string.format(
        Format,
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
  else
    io.write(string.format(Format, State.FileName, Ansi.Red, Ansi.Reset, string.format(...)))
  end

  State.Stop = true

  if Rua.DevMode then
    io.write(
      string.format(
        "%sLua:%s traceback:\n%s\n",
        Ansi.Blue,
        Ansi.Reset,
        debug.traceback():gsub("stack traceback:\n", ""):gsub("	", "   ")
      )
    )
  end
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

      if State.TokenCharacter == "0" then
        Tokenizer:Advance(State)

        if State.TokenCharacter == "x" or State.TokenCharacter == "X" then
          Tokenizer:Advance(State)

          while StringHasLetter("0123456789abcdefABCDEF", State.TokenCharacter) do
            Tokenizer:Advance(State)
          end

          local Digits = State.FileContent:sub(StartIndex + 2, State.FileIndex - 1)
          local Number = tonumber(Digits, 16)

          Tokenizer:AddToken(State, "Number", Number)
        elseif State.TokenCharacter == "b" or State.TokenCharacter == "B" then
          Tokenizer:Advance(State)

          while State.TokenCharacter == "0" or State.TokenCharacter == "1" do
            Tokenizer:Advance(State)
          end

          local Digits = State.FileContent:sub(StartIndex + 2, State.FileIndex - 1)
          local Number = tonumber(Digits, 2)

          Tokenizer:AddToken(State, "Number", Number)
        else
          while StringHasLetter(BaseDigits, State.TokenCharacter) do
            Tokenizer:Advance(State)
          end

          local Number = tonumber(State.FileContent:sub(StartIndex, State.FileIndex - 1))
          Tokenizer:AddToken(State, "Number", Number)
        end
      else
        while StringHasLetter(BaseDigits, State.TokenCharacter) do
          Tokenizer:Advance(State)
        end

        local Number = tonumber(State.FileContent:sub(StartIndex, State.FileIndex - 1))
        Tokenizer:AddToken(State, "Number", Number)
      end
    elseif State.TokenCharacter == '"' or State.TokenCharacter == "'" then
      local Quote = State.TokenCharacter
      Tokenizer:Advance(State)

      local StartIndex = State.FileIndex

      while State.TokenCharacter ~= Quote do
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
    if Token.Value == "true" or Token.Value == "false" then
      Parser:Advance(State)

      return {
        Type = "Boolean",
        Value = Token.Value == "true",
      }
    end

    Parser:Advance(State)

    local Expression = {
      Type = "Ident",
      Value = Token.Value,
    }

    if State.CurrentToken and State.CurrentToken.Value == "(" then
      Parser:Advance(State)

      Expression = {
        Type = "FunctionCall",
        Name = Token.Value,
        Arguments = Parser:ParseArgumentList(State),
      }

      local Kind = Parser:Expect(State, ")")
      if Kind == nil then
        return nil
      end
    end

    return Expression
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
  Statement.Body = Parser:ParseBlock(State, "end")
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
  elseif State.CurrentToken.Value == "end" then
    Parser:Advance(State)
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
      local Result = Parser:ParseStatement(State, true)
      return Result
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

  Logger:Error(State, "Failed to allocate a register")
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
    for _, Argument in ipairs(Ast.Arguments) do
      local ArgumentRegister = IrGenerator:GenerateIr(State, Argument)

      State.CurrentIr.Type = "Push"
      State.CurrentIr.Arguments = {
        [1] = ArgumentRegister,
      }
      IrGenerator:MarkNotUsed(State, ArgumentRegister)
      IrGenerator:NewIr(State)
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

    local ResultRegister = IrGenerator:AllocateRegister(State)

    State.CurrentIr.Type = "Pop"
    State.CurrentIr.Arguments = {
      [1] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "Function" then
    local EndLabel = IrGenerator:NewLabel(State)
    local FunctionLabel = IrGenerator:NewLabel(State)

    local FunctionNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Name)

    State.CurrentIr.Type = "LoadFunction"
    State.CurrentIr.Arguments = {
      [1] = FunctionLabel,
      [2] = FunctionNameRegister,
      [3] = #Ast.Arguments,
    }
    IrGenerator:MarkNotUsed(State, FunctionNameRegister)
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Jump"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = FunctionLabel,
    }
    IrGenerator:NewIr(State)

    for Index = #Ast.Arguments, 1, -1 do
      local Argument = Ast.Arguments[Index]
      local ArgumentNameRegister = IrGenerator:ConvertStringToIr(State, Argument.Value)
      local ArgumentRegister = IrGenerator:AllocateRegister(State)

      State.CurrentIr.Type = "Pop"
      State.CurrentIr.Arguments = {
        [1] = ArgumentRegister,
      }
      IrGenerator:NewIr(State)

      State.CurrentIr.Type = "VariableAssign"
      State.CurrentIr.Arguments = {
        [1] = ArgumentNameRegister,
        [2] = ArgumentRegister,
      }
      IrGenerator:MarkNotUsed(State, ArgumentNameRegister)
      IrGenerator:MarkNotUsed(State, ArgumentRegister)
      IrGenerator:NewIr(State)
    end

    for _, ChildAst in ipairs(Ast.Body) do
      IrGenerator:GenerateIr(State, ChildAst)
    end

    State.CurrentIr.Type = "Return"
    State.CurrentIr.Arguments = {}
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)
  elseif Ast.Type == "Number" then
    local ResultRegister = IrGenerator:AllocateRegister(State)
    State.CurrentIr.Type = "LoadNumber"
    State.CurrentIr.Arguments = {
      [1] = Ast.Value,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "String" then
    local ResultRegister = IrGenerator:AllocateRegister(State)
    State.CurrentIr.Type = "LoadString"
    State.CurrentIr.Arguments = {
      [1] = Ast.Value,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "Ident" then
    local VariableNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Value)
    local ResultRegister = IrGenerator:AllocateRegister(State)

    State.CurrentIr.Type = "GetVariable"
    State.CurrentIr.Arguments = {
      [1] = VariableNameRegister,
      [2] = ResultRegister,
    }

    IrGenerator:MarkNotUsed(State, VariableNameRegister)
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "Boolean" then
    local ResultRegister = IrGenerator:AllocateRegister(State)
    State.CurrentIr.Type = "LoadBoolean"
    State.CurrentIr.Arguments = {
      [1] = Ast.Value,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "VariableAssign" then
    local VariableNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Name)
    local VariableRegister = IrGenerator:GenerateIr(State, Ast.Value)

    State.CurrentIr.Type = "VariableAssign"
    State.CurrentIr.Arguments = {
      [1] = VariableNameRegister,
      [2] = VariableRegister,
    }

    IrGenerator:MarkNotUsed(State, VariableNameRegister)
    IrGenerator:MarkNotUsed(State, VariableRegister)
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
    local ElseLabel = IrGenerator:NewLabel(State)
    local EndLabel = IrGenerator:NewLabel(State)

    local ResultRegister = IrGenerator:GenerateIr(State, Ast.Condition)

    State.CurrentIr.Type = "JumpIfFalseRegister"
    State.CurrentIr.Arguments = {
      [1] = ElseLabel,
      [2] = ResultRegister,
    }
    IrGenerator:MarkNotUsed(State, ResultRegister)
    IrGenerator:NewIr(State)

    IrGenerator:GenerateBlock(State, Ast.Body)

    State.CurrentIr.Type = "Jump"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = ElseLabel,
    }
    IrGenerator:NewIr(State)

    if Ast.ElseIf then
      IrGenerator:GenerateIr(State, Ast.ElseIf)
    elseif Ast.Else then
      IrGenerator:GenerateBlock(State, Ast.Else)
    end

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)
  elseif Ast.Type == "BinaryExpression" then
    local LeftRegister = IrGenerator:GenerateIr(State, Ast.Left)
    local RightRegister = IrGenerator:GenerateIr(State, Ast.Right)
    local ResultRegister = IrGenerator:AllocateRegister(State)

    State.CurrentIr.Arguments = {
      [1] = LeftRegister,
      [2] = RightRegister,
      [3] = ResultRegister,
    }

    if Ast.Operator == "+" then
      State.CurrentIr.Type = "Add"
    elseif Ast.Operator == "-" then
      State.CurrentIr.Type = "Sub"
    elseif Ast.Operator == "/" then
      State.CurrentIr.Type = "Div"
    elseif Ast.Operator == "*" then
      State.CurrentIr.Type = "Mul"
    elseif Ast.Operator == "%" then
      State.CurrentIr.Type = "Mod"
    elseif Ast.Operator == "^" then
      State.CurrentIr.Type = "Pow"
    elseif Ast.Operator == "~=" then
      State.CurrentIr.Type = "NotEqual"
    elseif Ast.Operator == "==" then
      State.CurrentIr.Type = "Equal"
    elseif Ast.Operator == ">=" then
      State.CurrentIr.Type = "EqualOrGreaterThan"
    elseif Ast.Operator == "<=" then
      State.CurrentIr.Type = "EqualOrLessThan"
    elseif Ast.Operator == ">" then
      State.CurrentIr.Type = "GreaterThan"
    elseif Ast.Operator == "<" then
      State.CurrentIr.Type = "LessThan"
    elseif Ast.Operator == "&" then
      State.CurrentIr.Type = "NumberAnd"
    elseif Ast.Operator == "|" then
      State.CurrentIr.Type = "NumberOr"
    elseif Ast.Operator == "~" then
      State.CurrentIr.Type = "NumberXor"
    end
    IrGenerator:NewIr(State)

    IrGenerator:MarkNotUsed(State, LeftRegister)
    IrGenerator:MarkNotUsed(State, RightRegister)
    return ResultRegister
  end

  State.CurrentIr = { Arguments = {} }
end

function IrGenerator:Initalize(State)
  State.Ir.Registers = {}
  for _ = 1, 256 do
    table.insert(State.Ir.Registers, false)
  end
end

function Rua:GenerateIr(State)
  IrGenerator:Initalize(State)

  for _, Ast in ipairs(State.Ast) do
    IrGenerator:GenerateIr(State, Ast)
  end
end

local LuaGenerator = {}

function LuaGenerator:Initalize(State)
  State.Lua.Program = ""
end

function LuaGenerator:IrToLua(Ir, Level)
  if Ir.Type == "Label" then
    return string.format("function Label%d()\n", Ir.Arguments[1])
  else
    local Arguments = {}

    for _, Argument in ipairs(Ir.Arguments) do
      table.insert(Arguments, string.format("%q", Argument))
    end

    return string.format("%sRuaRuntime.%s(%s)\n", ("  "):rep(Level), Ir.Type, table.concat(Arguments, ", "))
  end
end

function LuaGenerator:IrProgramToLua(State)
  local Lua = ""
  local Level = 0
  local NotFirstLabel = false

  for _, Ir in ipairs(State.Ir.Program) do
    if Ir.Type == "Label" then
      Level = 1
      if NotFirstLabel then
        Lua = Lua .. "end\n"
      end
      Lua = Lua .. "\n"
      NotFirstLabel = true
    end
    if Ir.Type == "Test" then
      Lua = Lua .. "\n"
    end

    Lua = Lua .. LuaGenerator:IrToLua(Ir, Level)
  end

  if NotFirstLabel then
    Lua = Lua .. "end"
  end

  return Lua
end

function LuaGenerator:Generate(State)
  State.Lua.Program = LuaGenerator:IrProgramToLua(State)
end

function Rua:GenerateLua(State)
  LuaGenerator:Initalize(State)
  LuaGenerator:Generate(State)
end

local RuaRuntime = {}

function RuaRuntime:Initialize(State)
  State.Runtime.Registers = {}
  State.Runtime.Variables = {}
  State.Runtime.Functions = {}
  State.Runtime.Stack = {}
end

function RuaRuntime:GetRegister(State, RegisterIndex)
  local Register = State.Runtime.Registers[RegisterIndex]

  if Register == nil then
    Register = { Type = "Nil" }
    State.Runtime.Registers[RegisterIndex] = Register
  end

  return Register
end

function RuaRuntime:GetValueFromRegister(State, RegisterIndex)
  return RuaRuntime:GetRegister(State, RegisterIndex).Value
end

function RuaRuntime:SetRegister(State, RegisterIndex, Register)
  State.Runtime.Registers[RegisterIndex] = Register
end

function RuaRuntime:LoadString(State, String, RegisterIndex)
  State.Runtime.Registers[RegisterIndex] = {
    Type = "String",
    Value = String,
  }
end

function RuaRuntime:Push(State, RegisterIndex)
  local Register = RuaRuntime:GetRegister(State, RegisterIndex)

  table.insert(State.Stack, {
    Type = Register.Type,
    Value = Register.Value,
  })
end

function RuaRuntime:Pop(State, RegisterIndex)
  local Register = RuaRuntime:GetRegister(State, RegisterIndex)
  local Value = table.remove(State.Runtime.Stack)

  Register.Type = Value.Type
  Register.Value = Value.Value
end

function RuaRuntime.GetFunction(FunctionNameRegister, FunctionRegister)
  local FunctionName = RuaRuntime:GetValueFromRegister(FunctionNameRegister)
  local Function = RuaRuntime.Functions[FunctionName]

  RuaRuntime.Runtime.Registers[FunctionRegister] = {
    Type = "Function",
    Value = { Name = FunctionName, Function = Function },
  }
end

function RuaRuntime.CallFromRegister(FunctionRegister)
  local Function = RuaRuntime:GetValueFromRegister(FunctionRegister)

  local Arguments = RuaRuntime.Stack

  if Function.Function then
    Function.Function(table.unpack(Arguments))
  else
    Function.Function = _G[Function.Name]
    Function.Function(table.unpack(Arguments))
  end
end

Rua.Logger = Logger
Rua.Tokenizer = Tokenizer
Rua.Parser = Parser
Rua.IrGenerator = IrGenerator

-- File -> Tokenizer -> Tokens -> Parser -> Ast ->
-- Ir generator -> Ir -> LuaGenerator -> Lua

-- New idea: Compile Ir text to valid Lua then use loadstring to run it
-- No Vm at all

return Rua
