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
    ShowFaultLine = true,
    Bytecode = {
      Program = "",
      ProgramTable = {},
      Lables = {},
      Isa = {
        Opcodes = {
          GetFunction = 1,
          CallFromRegister = 2,
          LoadNumber = 3,
          LoadString = 4,
          LoadBoolean = 5,
          GetVariable = 6,
          LocalVariableAssign = 7,
          GlobalVariableAssign = 8,
          Push = 9,
          Pop = 10,
          Test = 11,
          Jump = 12,
          Label = 13,
          Add = 14,
          Sub = 15,
          Mul = 16,
          Div = 17,
          LoadFunction = 18,
        },

        InstructionArguments = {
          GetFunction = {
            [1] = "Register",
            [2] = "Register",
          },
          CallFromRegister = {
            [1] = "Register",
          },
          LoadNumber = {
            [1] = "Number",
            [2] = "Register",
          },
          LoadString = {
            [1] = "String",
            [2] = "Register",
          },
          LoadBoolean = {
            [1] = "Boolean",
            [2] = "Register",
          },
          GetVariable = {
            [1] = "Register",
            [2] = "Register",
          },
          LocalVariableAssign = {
            [1] = "Register",
            [2] = "Register",
          },
          GlobalVariableAssign = {
            [1] = "Register",
            [2] = "Register",
          },
          Push = {
            [1] = "Register",
          },
          Pop = {
            [1] = "Register",
          },
          Test = {
            [1] = "Register",
          },
          Jump = {
            [1] = "Label",
          },
          Label = {
            [1] = "Label",
          },
          Add = {
            [1] = "Register",
            [2] = "Register",
            [3] = "Register",
          },
          Sub = {
            [1] = "Register",
            [2] = "Register",
            [3] = "Register",
          },
          Mul = {
            [1] = "Register",
            [2] = "Register",
            [3] = "Register",
          },
          Div = {
            [1] = "Register",
            [2] = "Register",
            [3] = "Register",
          },
          LoadFunction = {
            [1] = "Label",
            [2] = "Register",
            [3] = "Number",
          },
        },
      },
    },
    Vm = {
      Pc = 1,
      Registers = {},
      Stack = {},
      LocalVariables = {},
      GlobalVariables = {},
      Functions = {},
      SkipInstruction = false,
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
  PrintTable(State.Tokens)
  io.write("\n")

  Rua:Parse(State)
  if State.Stop then
    return
  end
  PrintTable(State.Ast)
  io.write("\n")

  Rua:GenerateIr(State)
  if State.Stop then
    return
  end
  PrintTable(State.Ir.Program)
  io.write("\n")

  Rua:GenerateBytecode(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    io.open("Test.rua", "wb"):write(State.Bytecode.Program)
  end

  Rua:Execute(State)
end

local Logger = {}

function Logger:Error(State, ...)
  local SourceLine = GetLine(State.FileContent, State.Line)
  local HighlightedWord = HighlightWord(SourceLine, State.Row)

  local WordStart, WordFinish = GetWordStartAndFinish(SourceLine, State.Row)
  local WordLength = WordFinish - WordStart

  local Format = "%s:%d:%d: %sError:%s %s\n"
  if State.ShowFaultLine then
    Format = Format .. " %s\n%s%s^%s%s\n"
  end
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

  State.Stop = true

  if Rua.DevMode then
    print(debug.traceback():gsub("stack traceback:\n", ""))
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
      local StartIndex = State.FileIndex - 1
      local FirstDigit = true

      while StringHasLetter(BaseDigits, State.TokenCharacter) do
        Tokenizer:Advance(State)
        if TableHasString({ "x", "b" }, State.TokenCharacter) and FirstDigit then
          Tokenizer:Advance(State)
        end
        FirstDigit = false
      end

      local Number = tonumber(State.FileContent:sub(StartIndex, State.FileIndex))
      Tokenizer:AddToken(State, "Number", Number)
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
    for _, Argument in pairs(Ast.Arguments) do
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

      State.CurrentIr.Type = "LocalVariableAssign"
      State.CurrentIr.Arguments = {
        [1] = ArgumentNameRegister,
        [2] = ArgumentRegister,
      }
      IrGenerator:MarkNotUsed(State, ArgumentNameRegister)
      IrGenerator:MarkNotUsed(State, ArgumentRegister)
      IrGenerator:NewIr(State)
    end

    IrGenerator:GenerateIr(State, Ast.Body)

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

    State.CurrentIr.Type = (Ast.Local and "Local" or "Global") .. "VariableAssign"
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

    State.CurrentIr.Type = "Test"
    State.CurrentIr.Arguments = {
      [1] = ResultRegister,
    }
    IrGenerator:MarkNotUsed(State, ResultRegister)
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Jump"
    State.CurrentIr.Arguments = {
      [1] = ElseLabel,
    }
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
    end
    IrGenerator:NewIr(State)

    IrGenerator:MarkNotUsed(State, LeftRegister)
    IrGenerator:MarkNotUsed(State, RightRegister)
    return ResultRegister
  end

  State.CurrentIr = { Arguments = {} }
end

function IrGenerator:Initalize(State)
  State.ShowFaultLine = false
  State.Ir.Registers = {}
  for _ = 1, 256 do
    table.insert(State.Ir.Registers, false)
  end
end

function Rua:GenerateIr(State)
  IrGenerator:Initalize(State)

  for _, Ast in pairs(State.Ast) do
    IrGenerator:GenerateIr(State, Ast)
  end
end

local BytecodeGenerator = {}

function BytecodeGenerator:Write8(State, Value)
  table.insert(State.Bytecode.ProgramTable, string.char(Value))
end

function BytecodeGenerator:Write16(State, Value)
  BytecodeGenerator:Write8(State, Value % 256)
  BytecodeGenerator:Write8(State, math.floor(Value / 256) % 256)
end

function BytecodeGenerator:Write32(State, Value)
  BytecodeGenerator:Write8(State, Value % 256)
  BytecodeGenerator:Write8(State, math.floor(Value / 256) % 256)
  BytecodeGenerator:Write8(State, math.floor(Value / 65536) % 256)
  BytecodeGenerator:Write8(State, math.floor(Value / 16777216) % 256)
end

function BytecodeGenerator:WriteBoolean(State, Value)
  BytecodeGenerator:Write8(State, Value and 1 or 0)
end

function BytecodeGenerator:WriteDouble(State, Value)
  table.insert(State.Bytecode.ProgramTable, string.pack("<d", Value))
end

function BytecodeGenerator:FindLabels(State)
  local Offset = 1

  for _, Ir in ipairs(State.Ir.Program) do
    if Ir.Type == "Label" then
      local Label = Ir.Arguments[1]

      State.Bytecode.Labels[Label] = Offset
    else
      Offset = Offset + BytecodeGenerator:GetInstructionSize(State, Ir)
    end
  end
end

function BytecodeGenerator:Initalize(State)
  State.Bytecode.Program = ""
  State.Bytecode.ProgramTable = {}
  State.Bytecode.Labels = {}
  BytecodeGenerator:FindLabels(State)
end

function BytecodeGenerator:GetInstructionSize(State, Ir)
  local Size = 1

  for ArgumentIndex, ArgumentValue in pairs(Ir.Arguments) do
    local ArgumentType = State.Bytecode.Isa.InstructionArguments[Ir.Type][ArgumentIndex]

    if ArgumentType == "Register" then
      Size = Size + 1
    elseif ArgumentType == "Number" then
      Size = Size + 8
    elseif ArgumentType == "String" then
      Size = Size + 4 + #ArgumentValue
    elseif ArgumentType == "Boolean" then
      Size = Size + 1
    elseif ArgumentType == "Label" then
      Size = Size + 4
    end
  end

  return Size
end

function BytecodeGenerator:Generate(State, Ir)
  if Ir.Type == "Label" then
    return
  end

  local Instruction = State.Bytecode.Isa.Opcodes[Ir.Type]
  BytecodeGenerator:Write8(State, Instruction)

  for ArgumentIndex, ArgumentValue in ipairs(Ir.Arguments) do
    local ArgumentType = State.Bytecode.Isa.InstructionArguments[Ir.Type][ArgumentIndex]

    if ArgumentType == "Register" then
      BytecodeGenerator:Write8(State, ArgumentValue)
    elseif ArgumentType == "Number" then
      BytecodeGenerator:WriteDouble(State, ArgumentValue)
    elseif ArgumentType == "String" then
      BytecodeGenerator:Write32(State, #ArgumentValue)
      for Index = 1, #ArgumentValue do
        BytecodeGenerator:Write8(State, string.byte(ArgumentValue, Index))
      end
    elseif ArgumentType == "Boolean" then
      BytecodeGenerator:WriteBoolean(State, ArgumentValue)
    elseif ArgumentType == "Label" then
      local LabelAddress = State.Bytecode.Labels[ArgumentValue]
      BytecodeGenerator:Write32(State, LabelAddress)
    end
  end
end

function Rua:GenerateBytecode(State)
  BytecodeGenerator:Initalize(State)

  for _, Ir in ipairs(State.Ir.Program) do
    BytecodeGenerator:Generate(State, Ir)
  end

  State.Bytecode.Program = table.concat(State.Bytecode.ProgramTable)
end

local Vm = {}

function Vm:Read8(State)
  local Value = string.byte(State.Bytecode.Program, State.Vm.Pc)
  State.Vm.Pc = State.Vm.Pc + 1

  return Value
end

function Vm:Read16(State)
  local Value = Vm:Read8(State)
  Value = Value + Vm:Read8(State) * 256

  return Value
end

function Vm:Read32(State)
  local Value = Vm:Read8(State)
  Value = Value + Vm:Read8(State) * 256
  Value = Value + Vm:Read8(State) * 65536
  Value = Value + Vm:Read8(State) * 16777216

  return Value
end

function Vm:ReadDouble(State)
  local Value
  Value, State.Vm.Pc = string.unpack("<d", State.Bytecode.Program, State.Vm.Pc)

  return Value
end

function Vm:ReadString(State)
  local Length = Vm:Read32(State)
  local Value = State.Bytecode.Program:sub(State.Vm.Pc, State.Vm.Pc + Length - 1)

  State.Vm.Pc = State.Vm.Pc + Length

  return Value
end

function Vm:GetRegister(State, Register)
  return State.Vm.Registers[Register]
end

function Vm:ReadAndGetRegister(State)
  local RegisterIndex = Vm:Read8(State)
  return State.Vm.Registers[RegisterIndex], RegisterIndex
end

function Vm:GetStringFromRegister(State)
  local Register, RegisterIndex
  Register, RegisterIndex = Vm:ReadAndGetRegister(State)
  return Register.Value, RegisterIndex
end

function Vm:Execute(State)
  local Instruction = Vm:Read8(State)
  local Opcode

  for Key, Value in pairs(State.Bytecode.Isa.Opcodes) do
    if Value == Instruction then
      Opcode = Key
    end
  end

  if Opcode == "GetFunction" then
    local FunctionName = Vm:GetStringFromRegister(State)
    local FunctionRegister, FunctionRegisterIndex = Vm:ReadAndGetRegister(State)

    if not State.Vm.SkipInstruction then
      -- print("GetFunction", FunctionName, State.Vm.Functions[FunctionName], FunctionRegisterIndex)
      FunctionRegister.Type = "Function"
      FunctionRegister.Value = State.Vm.Functions[FunctionName]
    end
  elseif Opcode == "CallFromRegister" then
    local FunctionRegister, Index = Vm:ReadAndGetRegister(State)

    if not State.Vm.SkipInstruction then
      -- print("CallFromRegister", Index)
      State.Vm.Pc = FunctionRegister.Value.Address
    end
  elseif Opcode == "LoadFunction" then
    local FunctionAddress = Vm:Read32(State)
    local FunctionName = Vm:GetStringFromRegister(State)
    local FunctionArgumentCount = Vm:ReadDouble(State)

    if not State.Vm.SkipInstruction then
      State.Vm.Functions[FunctionName] = {
        Address = FunctionAddress,
        ArgumentCount = FunctionArgumentCount,
      }
      -- print("LoadFunction", FunctionName, FunctionAddress)
    end
  elseif Opcode == "LoadNumber" then
    local Number = Vm:ReadDouble(State)
    local ResultRegister = Vm:ReadAndGetRegister(State)

    if not State.Vm.SkipInstruction then
      ResultRegister.Value = Number
    end
  elseif Opcode == "LoadString" then
    local String = Vm:ReadString(State)
    local ResultRegister = Vm:ReadAndGetRegister(State)

    if not State.Vm.SkipInstruction then
      ResultRegister.Value = String
    end
  elseif TableHasString({ "Add", "Sub", "Div", "Mul" }, Opcode) then
    local LeftRegister = Vm:ReadAndGetRegister(State)
    local RightRegister = Vm:ReadAndGetRegister(State)
    local ResultRegister = Vm:ReadAndGetRegister(State)

    if not State.Vm.SkipInstruction then
      if Opcode == "Add" then
        ResultRegister.Value = LeftRegister.Value + RightRegister.Value
      elseif Opcode == "Sub" then
        ResultRegister.Value = LeftRegister.Value - RightRegister.Value
      elseif Opcode == "Div" then
        ResultRegister.Value = LeftRegister.Value / RightRegister.Value
      elseif Opcode == "Mul" then
        ResultRegister.Value = LeftRegister.Value * RightRegister.Value
      end
    end
  elseif Opcode == "Jump" then
    local Address = Vm:Read32(State)

    if not State.Vm.SkipInstruction then
      State.Vm.Pc = Address
    end
    -- uhhh
  elseif Opcode == "Push" then
    local Register = Vm:ReadAndGetRegister(State)

    if not State.Vm.SkipInstruction then
      table.insert(State.Vm.Stack, Register.Value)
    end
  elseif Opcode == "Pop" then
    local Register = Vm:ReadAndGetRegister(State)
    local Top = table.remove(State.Vm.Stack)

    if not State.Vm.SkipInstruction then
      Register.Type = Top.Type
      Register.Value = Top.Value
    end
  elseif Opcode == "Test" then
    local Register = Vm:ReadAndGetRegister(State)

    if not State.Vm.SkipInstruction then
      if Register.Value ~= 0 then
        State.Vm.SkipInstruction = true
      end
    end
  elseif TableHasString({ "LocalVariableAssign", "GlobalVariableAssign" }, Opcode) then
    local VariableName = Vm:GetStringFromRegister(State)
    local VariableRegister = Vm:ReadAndGetRegister(State)

    if not State.Vm.SkipInstruction then
      if Opcode == "LocalVariableAssign" then
        State.Vm.LocalVariables[VariableName] = VariableRegister.Value
      else
        State.Vm.GlobalVariables[VariableName] = VariableRegister.Value
      end
    end
  end
end

function Vm:Initalize(State)
  State.Vm.Pc = 1
  for Index = 1, 256 do
    State.Vm.Registers[Index] = {
      Type = "Nil",
      Value = nil,
    }
  end
end

function Vm:Run(State)
  local Result

  while State.Vm.Pc <= #State.Bytecode.Program do
    Result = Vm:Execute(State)
    State.Vm.SkipInstruction = false
  end

  return Result
end

function Rua:Execute(State)
  Vm:Initalize(State)
  return Vm:Run(State)
end

Rua.Logger = Logger
Rua.Tokenizer = Tokenizer
Rua.Parser = Parser
Rua.IrGenerator = IrGenerator
Rua.BytecodeGenerator = BytecodeGenerator
Rua.Vm = Vm

-- File -> Tokenizer -> Tokens -> Parser -> Ast ->
-- Ir generator -> Ir -> Bytecode generator -> Bytecode ->
-- Register-based VM

-- TODO: A working register-based VM

return Rua
