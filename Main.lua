local TinyLua = require("Rua")

local State = TinyLua.new()

local FileName = nil
for ArgumentIndex, Argument in ipairs(arg) do
  FileName = Argument
end

if FileName == nil then
  return
end

TinyLua:Run(State, FileName)
