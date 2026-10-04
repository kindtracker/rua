local Rua = {}

local BaseIdent = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local BasePunct = "(){}[];,:."
local BaseDigits = "0123456789"
local BaseOperators = "+-*/^%#"

local function StringHasLetter(String, Letter)
  for Character in String:gmatch(".") do
    if Character == Letter then
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

      print("Ident", State.FileContent:sub(StartIndex, State.FileIndex - 1))
    elseif StringHasLetter(BasePunct, State.TokenCharacter) then
      local Punct = Tokenizer:Advance(State)

      print("Punct", Punct)
    else
      break
    end
  end
end

Rua.Tokenizer = Tokenizer

return Rua
