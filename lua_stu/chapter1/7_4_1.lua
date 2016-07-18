function allwords(f)
    for l in io.lines() do
        for w in string.find(l, "%w+") do
            f(w)
        end
    end
end

allwords(print)
