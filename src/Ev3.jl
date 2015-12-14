module Ev3

using Behaviors

import Base: parse, read, write

export Device,
       Sensor, 
       Motor, 
       connect_to_robot

SYS_ROOT = "/sys"

include("nodes.jl")
include("devices.jl")
include("channels.jl")

end