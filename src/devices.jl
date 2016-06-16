abstract AbstractDevice

immutable Device
    node::AbstractNode
end

immutable Motor <: AbstractDevice
    node::AbstractNode
    commands::Set

    Motor(node::AbstractNode) = begin
        commands = Set(split(chomp(read(node, "commands"))))
        new(node, commands)
    end
end
Motor(port::AbstractString) = Motor(find_device_on_port(LocalNode("$(SYS_ROOT)/class/tacho-motor"), port))

function Motor(port::AbstractString, socket::Socket)
    Motor(find_device_on_port(RemoteNode("$(SYS_ROOT)/class/tacho-motor", socket), port))
end

immutable Sensor <: AbstractDevice
    node::AbstractNode
end
Sensor(port::AbstractString) = Sensor(find_device_on_port(LocalNode("$(SYS_ROOT)/class/lego-sensor"), port))

function Sensor(port::AbstractString, socket::Socket)
    Sensor(find_device_on_port(RemoteNode("$(SYS_ROOT)/class/lego-sensor", socket), port))
end

write(device::AbstractDevice, path::AbstractString, data::AbstractString) = write(device.node, path, data)
read(device::AbstractDevice, args...) = read(device.node, args...)
read(node::AbstractNode, path::AbstractString, _type::Union{Integer, AbstractFloat}) = parse(_type, read(node, path))

function find_device_on_port(node::RemoteNode, port_name)
    for device in list(node)
        devnode = RemoteNode("$(node.path)/$(device)", node.socket)
        if strip(read(devnode, "address")) == port_name
            return devnode
        end
    end
    error("Could not find device with address: $(port_name) on node: $(node)")
end
