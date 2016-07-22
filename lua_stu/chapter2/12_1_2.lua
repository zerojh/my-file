function basicSerialize (o)
    if type(o) == "number" then
        return tostring(o)
    else       -- assume it is a string
        return string.format("%q", o)
    end
end

function save (name, value, saved)
    saved = saved or {}         -- initial value
    io.write(name, " = ")
    if type(value) == "number" or type(value) == "string" then
        io.write(basicSerialize(value), "\n")
    elseif type(value) == "table" then
        if saved[value] then     -- value already saved?
            -- use its previous name
            io.write(saved[value], "\n")
        else
            saved[value] = name  -- save name for next time
            io.write("{}\n")     -- create a new table
            for k,v in pairs(value) do  -- save its fields
                local fieldname = string.format("%s[%s]", name,
                basicSerialize(k))
                save(fieldname, v, saved)
            end
        end
    else
        error("cannot save a " .. type(value))
    end
end

a = {x=1, y=2;{3,4,5}}
a[2]=a
a.z=a[1]

save('a', a)
