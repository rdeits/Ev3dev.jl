immutable Attribute{T, Read, Write}
    name::Symbol
    stream::IOStream
end

function call{T, Read, Write}(::Type{Attribute{T, Read, Write}}, brick::Brick, relative_path::AbstractString, name::Symbol)
    path = joinpath(brick.root_path, relative_path, string(name))
    isfile(path) || error("file not found: $path")
    Read && (isreadable(path) || error("read access for attribute $(path) was requested, but file is not readable"))
    Write && (iswritable(path) || error("write access for attribute $(path) was requested, but file is not writable"))
    stream = open(path, Read, Write, false, Write, false)
    Attribute{T, Read, Write}(name, stream)
end

typealias ReadOnly{T} Attribute{T, true, false}
typealias WriteOnly{T} Attribute{T, false, true}
typealias ReadWrite{T} Attribute{T, true, true}

parse(::Type{ASCIIString}, s::ASCIIString) = s
parse(::Type{Vector{ASCIIString}}, s::ASCIIString) = split(s)

call{T, X}(attr::Attribute{T, true, X}) = parse(T, chomp(strip(readline(seekstart(attr.stream)), '\0')))
function call{T, X}(attr::Attribute{T, X, true}, value::T)
    write(seekstart(attr.stream), string(value))
    flush(attr.stream)
end
