using Base.Test
using Ev3

include("mock.jl")

let
    mktempdir() do dir
        @show dir
        mock_robot(dir, [(:large_motor, "outA"),
                         (:large_motor, "outB"),
                         (:medium_motor, "outC"),
                         (:ultrasound_sensor, "inA")])
        run(`ls $(dir)`)

        brick = Brick(dir)
        large_motors = find_devices(LargeMotor, brick)
        @test length(large_motors) == 2

        medium_motors = find_devices(MediumMotor, brick)
        @test length(medium_motors) == 1

        right_motor = find_device_at_address(LargeMotor, brick, "outA")
        @test right_motor.io.address() == "outA"

        ultrasound_sensor = find_devices(UltrasoundSensor, brick)[1]

        @test scaled_values(ultrasound_sensor) == [65.0]
    end
end
