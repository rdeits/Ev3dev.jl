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

function Motor(port::AbstractString, hostname::AbstractString)
    Motor(find_device_on_port(RemoteNode("$(SYS_ROOT)/class/tacho-motor", hostname), port))
end

immutable Sensor <: AbstractDevice
    node::AbstractNode
end
Sensor(port::AbstractString) = Sensor(find_device_on_port(LocalNode("$(SYS_ROOT)/class/lego-sensor"), port))

function Sensor(port::AbstractString, hostname::AbstractString)
    Sensor(find_device_on_port(RemoteNode("$(SYS_ROOT)/class/lego-sensor", hostname), port))
end

write(device::AbstractDevice, path::AbstractString, data::AbstractString) = write(device.node, path, data)
read(device::AbstractDevice, args...) = read(device.node, args...)
read(node::AbstractNode, path::AbstractString, _type::Union{Integer, AbstractFloat}) = parse(_type, read(node, path))