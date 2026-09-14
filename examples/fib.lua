local function Fib(N)
	if N <= 1 then
		return N
	end
	return Fib(N - 1) + Fib(N - 2)
end

print(Fib(10))
