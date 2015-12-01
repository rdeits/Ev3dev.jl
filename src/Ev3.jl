module Ev3

using ZMQ
import Base: parse, read, write

export Device, Sensor, Motor, run_forever, stop

SYS_ROOT = "/sys"

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
    return split(bytestring(out), "\n")
end

function find_device_on_port(node::RemoteNode, port_name)
    for device in list(node)
        devnode = RemoteNode("$(node.path)/$(device)", node.hostname)
        if strip(read(devnode, "port_name")) == port_name
            return devnode
        end
    end
end

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


macro readable(name, T, parser)
    return quote
        function ($(esc(name)))(dev::($T))
            $(parser)(read(dev, $(esc("$(name)"))))
        end
    end
end

macro writeable(name, T, validator)
    return quote
        function ($(esc(name)))(dev::($T), value)
            if !($(validator)(value))
                error("Validation function: ", $(validator), "failed with value: ", value)
            end
            write(dev, $(esc("$(name)")), string(value))
        end
    end
end

macro readwriteable(name, T, parser, validator)
    return quote
        function ($(esc(name)))(dev::($T), value)
            if !($(validator)(value))
                error("Validation function: ", $(validator), " failed with value: ", value)
            end
            write(dev, $(esc("$(name)")), string(value))
        end
        function ($(esc(name)))(dev::($T))
            $(parser)(read(dev, $(esc("$(name)"))))
        end
    end
end

as_string(s) = strip(s)
as_int(x) = parse(Int, x)
as_float(x) = parse(Float64, x)
as_string_set(x) = Set(split(chomp(x)))
is_positive(x) = x > 0

@readable port_name AbstractDevice as_string
@readable commands AbstractDevice as_string_set
@readable driver_name AbstractDevice as_string
@readable fw_version AbstractDevice as_string

@readable decimals Sensor as_int
@readable num_values Sensor as_int
@readable value0 Sensor as_int
@readable value1 Sensor as_int
@readable value2 Sensor as_int
@readable value3 Sensor as_int
@readable modes Sensor as_string_set
@readable mode Sensor as_string
@readable bin_data Sensor as_string
@readable bin_data_format Sensor as_string
@readwriteable poll_ms Sensor as_int is_positive

@readable position Motor as_int
@readwriteable speed_sp Motor as_int is_positive
@readable count_per_rot Motor as_int
@readable duty_cycle Motor as_int
@readwriteable duty_cycle_sp Motor as_int is_positive
@readwriteable encoder_polarity Motor as_string x -> x == "normal" || x == "inversed"
@readwriteable polarity Motor as_string x-> x == "normal" || x == "inversed"
@readwriteable speed_regulation Motor as_string x-> x == "on" || x == "off"
@readwriteable(speed_sp,
               Motor,
               as_string,
               x-> x > 0)

@readwriteable command Motor as_string x->true # todo: validate
@readwriteable stop_command Motor as_string x->true # todo: validate

write(device::AbstractDevice, path::AbstractString, data::AbstractString) = write(device.node, path, data)
read(device::AbstractDevice, args...) = read(device.node, args...)
read(node::AbstractNode, path::AbstractString, _type::Union{Integer, AbstractFloat}) = parse(_type, read(node, path))

function run_at_speed(motor::Motor, speed=100)
    speed_regulation(motor, "on")
    speed_sp(motor, speed)
    command(motor, "run-forever")
end

function stop(motor::Motor, stop_command_name="coast")
    stop_command(motor, stop_command_name)
    command(motor, "stop")
end


end