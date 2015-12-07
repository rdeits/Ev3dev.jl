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
is_positive_integer(x) = x > 0 && typeof(x) <: Integer
is_integer(x) = typeof(x) <: Integer
function in_set(args...)
    set = Set(args)
    x -> in(x, set)
end

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
@readwriteable poll_ms Sensor as_int is_positive_integer

@readable position Motor as_int
@readable count_per_rot Motor as_int
@readable duty_cycle Motor as_int
@readwriteable duty_cycle_sp Motor as_int is_positive_integer
@readwriteable speed_sp Motor as_int is_integer
@readwriteable position_sp Motor as_int is_integer
@readwriteable encoder_polarity Motor as_string in_set("normal", "inversed")
@readwriteable polarity Motor as_string in_set("normal", "inversed")
@readwriteable speed_regulation Motor as_string in_set("on", "off")
@readwriteable command Motor as_string x->true # todo: validate
@readwriteable stop_command Motor as_string x->true # todo: validate

function values(sensor::Sensor)
    values = Array(Float64, num_values(sensor))
    dec = decimals(sensor)
    multiplier = 10.0 ^ (-dec)
    for j = 1:length(values)
        values[j] = multiplier * parse(Int, chomp(read(sensor, "value$(j-1)")))
    end
    values
end

function run_at_speed(motor::Motor, speed=100)
    speed_regulation(motor, "on")
    speed_sp(motor, speed)
    command(motor, "run-forever")
end

function stop(motor::Motor, stop_command_name="coast")
    stop_command(motor, stop_command_name)
    command(motor, "stop")
end

