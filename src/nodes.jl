using ZMQ

CONTEXT = Context()

abstract AbstractNode

immutable LocalNode <: AbstractNode
    path::AbstractString
end

immutable RemoteNode <: AbstractNode
    path::AbstractString
    hostname::AbstractString
    socket::Socket
end

function RemoteNode(path::AbstractString, hostname::AbstractString)
    socket = Socket(CONTEXT, REQ)
    ZMQ.connect(socket, "tcp://$(hostname):5555")
    RemoteNode(path, hostname, socket)
end

function write(node::LocalNode, path::AbstractString, data::AbstractString)
    open(f -> write(f, data), joinpath(node.path, path))
end

function write(node::RemoteNode, path::AbstractString, data::AbstractString)
    command = "w:$(data):$(node.path)/$(path)"
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

function find_device_on_port(node::RemoteNode, port_name)
    for device in list(node)
        devnode = RemoteNode("$(node.path)/$(device)", node.hostname)
        if strip(read(devnode, "port_name")) == port_name
            return devnode
        end
    end
    error("Could not find device with port_name: $(port_name) on node: $(node)")
end
