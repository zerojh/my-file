

function fwrite(fmt, ...)
    return io.write(string.format(fmt, unpack(arg)))
end

function BEGIN()
    io.write([[
    <html>
    <head><title>Projects using that</title></head>
    <body bgcolor="#FFFFFF">
    Here are brief description of some projects around the world that 
    use <a href="home.html">Lua</a>
    ]])
end

function entry0(o)
    N = N + 1
    local title = o.title or '(no title)'
    fwrite('<li><a href="#%d">%s</a>\n', N, title)
end

function entry1(o)
    N = N + 1
    local title = o.title or o.org or 'org'
    fwrite('<hr>\n<h3>')
    local href = ''

    if o.url then
        href = string.format(' href="%s"', o.url)
    end
    fwrite('<a name="%d"%s>%s</a>\n', N, href, title)

    if o.title and o.org then
        fwrite('\n<small><em>%s</em></small>', o.org)
    end
    fwrite('\n</h3>')

    if o.description then
        fwrite('%s', string.sub(o.description, '\n\n\n*', '<p>\n'))
        fwrite('<p>')
    end

    if o.email then
        fwrite('Contact: <a href="mailto:%s">%s</a>\n', o.email, o.contact or o.email)
    elseif o.contact then
        fwrite('Contact: %s\n', o.contact)
    end
end

function END()
    fwrite('</body></html>\n')
end


