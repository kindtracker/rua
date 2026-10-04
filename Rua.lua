local Rua = {}

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

local WhiteSpace = "\n\t\r "

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

function Rua.new()
  return {
    FileName = "",
    FileContent = "",
    FileIndex = 0,
    TokenCharacter = "",
  }
end

function Rua:Run(State, FileName)
  State.FileName = FileName
  State.FileContent = io.open(FileName, "r"):read("*a")
  local Tokens = Rua:Tokenize(State)
end

local Tokenizer = {}

function Tokenizer:Advance(State)
  local Character = State.TokenCharacter
  State.FileIndex = State.FileIndex + 1
  State.TokenCharacter = State.FileContent:sub(State.FileIndex, State.FileIndex)

  return Character
end

function Tokenizer:Initialize(State)
  State.FileIndex = 0
  Tokenizer:Advance(State)
end

function Rua:Tokenize(State)
  Tokenizer:Initialize(State)

  while true do
    if StringHasLetter(BaseIdent, State.TokenCharacter) then
      local StartIndex = State.FileIndex

      while StringHasLetter(BaseIdent, State.TokenCharacter) do
        Tokenizer:Advance(State)
      end

      local Ident = State.FileContent:sub(StartIndex, State.FileIndex - 1)
      local IsKeyword = TableHasString(BaseKeywords, Ident)
      print(IsKeyword and "Keyword" or "Ident", Ident)
    elseif StringHasLetter(BasePunct, State.TokenCharacter) then
      local Punct = Tokenizer:Advance(State)

      print("Punct", Punct)
    elseif StringHasLetter(BaseOperators, State.TokenCharacter) then
      local Operator = Tokenizer:Advance(State)

      print("Operator", Operator)
    elseif State.TokenCharacter == '"' or State.TokenCharacter == "'" then
      Tokenizer:Advance(State)
      local StartIndex = State.FileIndex

      while State.TokenCharacter ~= '"' and State.TokenCharacter ~= "'" do
        local Character = Tokenizer:Advance(State)
        if Character == "\\" then
          Tokenizer:Advance(State) -- TODO: Handle string properly
        end
      end
      Tokenizer:Advance(State)

      print("String", State.FileContent:sub(StartIndex, State.FileIndex - 2))
    elseif StringHasLetter(WhiteSpace, State.TokenCharacter) then
      Tokenizer:Advance(State)
    else
      print("Unknown", State.TokenCharacter)
      break
    end
  end
end

Rua.Tokenizer = Tokenizer

return Rua
