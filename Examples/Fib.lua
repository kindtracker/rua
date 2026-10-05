local function Fib(Number)
  if Number == 1 then
    return 1
  elseif Number == 0 then
    return 0
  end
  return Fib(Number - 1) + Fib(Number - 2)
end

print(Fib(8))
