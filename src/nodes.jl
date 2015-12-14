using ZMQ

CONTEXT = Context()

abstract AbstractNode

immutable LocalNode <: AbstractNode
    path::AbstractString
end

immutable RemoteNode <: AbstractNode
    path::AbstractString
    socket::Socket
end

function connect_to_robot(hostname::AbstractString)
    socket = Socket(CONTEXT, REQ)
    ZMQ.connect(socket, "tcp://$(hostname):5555")
    socket
end

function write(node::LocalNode, relative_path::AbstractString, data::AbstractString)
    open(f -> write(f, data), joinpath(node.path, relative_path))
end

function write(node::RemoteNode, relative_path::AbstractString, data::AbstractString)
    command = "w:$(data):$(node.path)/$(relative_path)"
    ZMQ.send(node.socket, command)
    msg = ZMQ.recv(node.socket)
    out = convert(IOStream, msg)
    seek(out, 0)
    return bytestring(out)
end

function read(node::RemoteNode, path::AbstractString)
    command = "r:$(node.path)/$(path)"
    ZMQ.send(node.socket, command)
    msg = ZMQ.recv(node.socket)
    out = convert(IOStream, msg)
    seek(out, 0)
    return bytestring(out)
end

function list(node::RemoteNode)
    command = "l:$(node.path)"
    ZMQ.send(node.socket, command)
    msg = ZMQ.recv(node.socket)
    out = convert(IOStream, msg)
    seek(out, 0)
    return split(chomp(bytestring(out)), "\n")
end

