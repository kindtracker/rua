local TinyLua = {}

local BaseIdent = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local BaseDigits = "0123456789"
local BaseOperators = "+-*/^%#"

function TinyLua.new()
  return {}
end

function TinyLua:Run(State, FileName)
  State.CurrentFileName = FileName
  State.CurrentFileContent = io.open(FileName, "a"):read("*a")
  local Tokens = TinyLua:Tokenize(State)
end

local Tokenizer = {}

function Tokenizer:Advance(State)
  State.CurrentIndex = State.CurrentIndex + 1
  State.CurrentCharacter = State.CurrentFileContent[State.CurrentIndex]
end

function Tokenizer:Initialize()
  State.CurrentIndex = 0
end

function TinyLua:Tokenize(State)
  print(State.CurrentCharacter)
end

TinyLua.Tokenizer = Tokenizer

return TinyLua
