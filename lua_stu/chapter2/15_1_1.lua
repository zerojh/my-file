
P ={}
complex = P

-- defines a constant `i'
P.i = {r = 0, i = 1}

function P.new (r, i) return {r=r, i=i} end

function P.add (c1, c2)
    return P.new(c1.r + c2.r, c1.i + c2.i)
end

function P.sub (c1, c2)
    return P.new(c1.r - c2.r, c1.i - c2.i)
end

function P.mul (c1, c2)
    return P.new(c1.r*c2.r - c1.i*c2.i,
    c1.r*c2.i + c1.i*c2.r)
end

function P.inv (c)
    local n = c.r^2 + c.i^2
    return P.new(c.r/n, -c.i/n)
end

return complex
