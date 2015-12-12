module Ev3

using Behaviors

import Base: parse, read, write

export Device,
       Sensor, 
       Motor

SYS_ROOT = "/sys"

include("nodes.jl")
include("devices.jl")
include("channels.jl")
# include("Behaviors.jl")
# include("mapping_behaviors.jl")
# include("Mapping.jl")

end