local Rua = {}

local BaseIdent = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local BaseDigits = "0123456789"
local BaseOperators = "+-*/^%#"

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
  State.FileIndex = State.FileIndex + 1
  State.TokenCharacter = State.FileContent:sub(State.FileIndex, 1)
end

function Tokenizer:Initialize(State)
  State.FileIndex = 0
  Tokenizer:Advance(State)
end

function Rua:Tokenize(State)
  Tokenizer:Initialize(State)

  print(State.TokenCharacter)
end

Rua.Tokenizer = Tokenizer

return Rua
