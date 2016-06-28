type MockAttribute
    name::AbstractString
    read::Bool
    write::Bool
    contents::AbstractString
end

function make_file(attr::MockAttribute, path::AbstractString)
    file_path = joinpath(path, attr.name)
    open(file_path, "w") do f
        write(f, attr.contents)
    end
    mode = 0o000
    if attr.read
        mode += 0o444
    end
    if attr.write
        mode += 0o222
    end
    chmod(file_path, mode)
end

function mock_device(path, attribute_data, address)
    attributes = MockAttribute[MockAttribute(data...) for data in attribute_data]
    push!(attributes, MockAttribute("address", true, false, address))
    for attr in attributes
        make_file(attr, path)
    end
end

const attributes = Dict(
:large_motor => [
    ("commands", true, false, "run-forever run-timed stop"),
    ("driver_name", true, false, "lego-ev3-l-motor"),
    ("command", false, true, ""),
    ("count_per_rot", true, false, "720"),
    ("duty_cycle", true, false, "100"),
    ("duty_cycle_sp", true, true, "100"),
    ("speed_sp", true, true, "100"),
    ("position_sp", true, true, "90"),
    ("position", true, true, "0"),
    ("polarity", true, true, "normal"),
    ("stop_command", true, true, "brake"),
    ("stop_commands", true, false, "brake coast hold")
],
:medium_motor => [
    ("commands", true, false, "run-forever run-timed stop"),
    ("driver_name", true, false, "lego-ev3-m-motor"),
    ("command", false, true, ""),
    ("count_per_rot", true, false, "720"),
    ("duty_cycle", true, false, "100"),
    ("duty_cycle_sp", true, true, "100"),
    ("speed_sp", true, true, "100"),
    ("position_sp", true, true, "90"),
    ("position", true, true, "0"),
    ("polarity", true, true, "normal"),
    ("stop_command", true, true, "brake"),
    ("stop_commands", true, false, "brake coast hold")
],
:ultrasound_sensor => [
    ("commands", true, false, ""),
    ("driver_name", true, false, "lego-ev3-us"),
    ("command", false, true, ""),
    ("value0", true, false, "650"),
    ("value1", true, false, "0"),
    ("value2", true, false, "0"),
    ("value3", true, false, "0"),
    ("value4", true, false, "0"),
    ("value5", true, false, "0"),
    ("value6", true, false, "0"),
    ("value7", true, false, "0"),
    ("num_values", true, false, "1"),
    ("decimals", true, false, "1"),
    ("modes", true, false, "US_DIST_CM"), # todo: check these
    ("mode", true, true, "US_DIST_CM"),
    ("bin_data", true, false, ""), # todo: fill this in
    ("bin_data_format", true, false, ""), # todo: fill in
    ("poll_ms", true, true, "100")
]
)

const class_paths = Dict(
:large_motor => "sys/class/tacho-motor/motor",
:medium_motor => "sys/class/tacho-motor/motor",
:ultrasound_sensor => "sys/class/lego-sensor/sensor"
)

function mock_robot(path, devices::AbstractVector{Tuple{Symbol, ASCIIString}})
    for (device, address) in devices
        @show device address
        i = 0
        local device_path
        while true
            device_path = joinpath(path, class_paths[device] * "$(i)")
            if !isdir(device_path)
                break
            end
            i += 1
        end
        @show device_path
        mkpath(device_path)
        mock_device(device_path, attributes[device], address)
    end
end
