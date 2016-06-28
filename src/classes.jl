abstract Class{Name}

function call{T <: Class}(::Type{T}, brick::Brick, path::AbstractString)
    attr = T()
    for name in fieldnames(T)
        field_type = fieldtype(T, name)
        setfield!(attr, name, field_type(brick, path, name))
    end
    attr
end

type TachoMotorClass <: Class{:tacho_motor}
    address::ReadOnly{ASCIIString}
    commands::ReadOnly{Vector{ASCIIString}}
    driver_name::ReadOnly{ASCIIString}
    command::WriteOnly{ASCIIString}
    count_per_rot::ReadOnly{Int}
    duty_cycle::ReadOnly{Int}
    duty_cycle_sp::ReadWrite{Int}
    speed_sp::ReadWrite{Int}
    position_sp::ReadWrite{Int}
    position::ReadWrite{Int}
    polarity::ReadWrite{ASCIIString}
    stop_command::ReadWrite{ASCIIString}
    stop_commands::ReadOnly{Vector{ASCIIString}}

    TachoMotorClass() = new()
end


type LegoSensorClass <: Class{:lego_sensor}
    address::ReadOnly{ASCIIString}
    commands::ReadOnly{Vector{ASCIIString}}
    driver_name::ReadOnly{ASCIIString}
    command::WriteOnly{ASCIIString}
    value0::ReadOnly{Int}
    value1::ReadOnly{Int}
    value2::ReadOnly{Int}
    value3::ReadOnly{Int}
    value4::ReadOnly{Int}
    value5::ReadOnly{Int}
    value6::ReadOnly{Int}
    value7::ReadOnly{Int}
    num_values::ReadOnly{Int}
    decimals::ReadOnly{Int}
    modes::ReadOnly{Vector{ASCIIString}}
    mode::ReadWrite{ASCIIString}
    bin_data::ReadOnly{ASCIIString}
    bin_data_format::ReadOnly{ASCIIString}
    poll_ms::ReadWrite{Int}

    LegoSensorClass() = new()
end

@generated name{C <: Class}(::Type{C}) = :("$(C.super.parameters[1])")
@generated class_path{C <: Class}(::Type{C}) = :("$(joinpath("sys/class", replace(string(name(C)), '_', '-')))")
