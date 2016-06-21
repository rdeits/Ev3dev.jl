module Ev3

import Base: read, parse, write, call

immutable Brick
    root_path::AbstractString

    Brick(root_path::AbstractString="/") = new(root_path)
end

include("attributes.jl")
include("device.jl")
include("device_types.jl")
include("higher_level_commands.jl")

export Brick,
       LargeMotor,
       MediumMotor,
       UltrasoundSensor,
       ColorSensor,
       TouchSensor,
       GyroSensor,
       find_devices,
       find_device_at_address,
       scaled_values,
       command,
       run,
       servo_absolute,
       servo_relative,
       stop,
       Degrees,
       Radians


end
