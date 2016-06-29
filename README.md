# Ev3dev

[![Build Status](https://travis-ci.org/rdeits/Ev3dev.jl.svg?branch=master)](https://travis-ci.org/rdeits/Ev3dev.jl)
[![codecov](https://codecov.io/gh/rdeits/Ev3dev.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/rdeits/Ev3dev.jl)

This package provides a [Julia](http://julialang.org/) interface to the [ev3dev](http://www.ev3dev.org/) project, a custom operating system that runs on the [Lego Mindstorms EV3](http://www.lego.com/en-us/mindstorms/products/31313-mindstorms-ev3) and the Raspberry Pi-based [BrickPi](http://www.dexterindustries.com/BrickPi/). It provides both a low-level interface to the input and output attributes of each device attached to the robot as well as a few higher level functions to automate common tasks.

# Caveats

As of this writing (June 2016), I have been unable to get any version of Julia working directly onboard the Mindstorms EV3 brick. Instead, the easiest way to get running with Mindstorms and Julia is to hook up a Raspberry Pi to the EV3 and use the Pi to run Julia and control the robot remotely. Fortunately, this should be pretty easy (see [Raspberry Pi Setup](#raspberry_pi_setup)). Of course, you're welcome to use any other microcomputer like the BeagleBone, but these instructions will focus on the Pi because it's the platform I've personally been using.  

# Raspberry Pi Setup

Running Julia on the EV3 is not currently possible, but running it on a Raspberry Pi is reasonably easy. Julia v0.4.6 builds without any errors on the Raspberry Pi 3 and should build on other Pi versions as well. For instructions on how to build Julia on the Raspberry Pi, check out [Julia on ARM](https://github.com/JuliaLang/julia/blob/master/README.arm.md).

Once you have Julia working on the Raspberry Pi, it's easy to remotely control the EV3. Here's what you'll need to do:

1. Download an ev3dev image from the [ev3dev release page](https://github.com/ev3dev/ev3dev/releases). This package was built to work with `ev3dev-jessie-2015-12-30`.
1. Flash that image to a micro SD card. The [ev3dev getting started page](http://www.ev3dev.org/docs/getting-started/) has a tutorial on how to write to the SD card.
1. Insert that micro SD card into your Mindstorms EV3 brick and turn the EV3 on
1. Use a mini USB cable to connect one of the Pi's USB ports to the `PC` port on the EV3. This will allow the Pi and the EV3 to communicate.
1. Optionally, use a micro USB cable to connect the USB port on the EV3 to the micro USB power port on the Pi. This will allow the EV3 to power the Rasbperry Pi, even when it's running on battery.
1. Set up the network connection over USB between the EV3 and Raspberry Pi. We're not going to bother [getting internet access on the EV3](http://www.ev3dev.org/docs/tutorials/connecting-to-the-internet-via-usb/); instead, we'll just do enough to get the two devices to talk to one another:
    1. On the EV3 main menu, select *Wireless and Networks*, then *All Network Connections*, then *Wired*. Select *Connect* and then enable *Connect automatically* so you won't have to do these steps again in the future
    2. Wait a minute or two until you see an IP address appear at the top of the EV3 screen.
    2. From the Pi, you should now be able to do: `ssh robot@ev3dev.local` with the default password of `maker`.
1. Mount the `ev3dev` virtual files on the Raspberry Pi over sshfs. This will enable you to read and write the special `ev3dev` files that control the motors and sensors directly from the Pi, as if it were the EV3 itself. From the Pi, do:
    * `mkdir ~/Ev3`
    * `sshfs -o no_readahead,cache=no robot@ev3dev.local:/ ~/Ev3`

If all went well, you should now be able to access the `ev3dev` sensor and motor control files directly from the Pi. Try plugging a sensor into one of the sensor ports and then, from the Pi:

```
cat ~/Ev3/sys/class/lego-sensor/sensor0/driver_name
```

# Installing Ev3dev.jl

This package is not yet registered, but you can install it with:

```julia
Pkg.clone("git://github.com/rdeits/Ev3dev.jl.git")
```

# Usage

To use `Ev3dev.jl`, we first have to define a `Brick`, which represents a single EV3 or BrickPi device. To do that, we need to know where the root of the `ev3dev` filesystem is. If you're on a BrickPi, it's probably just `"/"`. If you mounted an EV3 over sshfs as in the previous step, it's `"/home/pi/Ev3"`.

```julia
using Ev3dev
brick = Brick("/home/pi/Ev3")
```

Now we can find sensors or motors attached to that brick:

```julia
ultrasound_sensors = find_devices(UltrasoundSensor, brick)
```

`find_devices` finds all of the devices of a particular type attached to the EV3. If we only have one sensor of that type, then we can just take the first element of the list it returns:

```julia
ultrasound_sensor = find_devices(UltrasoundSensor, brick)[1]
```

If we have multiple devices, we may want to specify which physical port a given device is connected to. Let's say we have two large motors attached to the same brick. To find the motor plugged into port `outB`, we can do:

```julia
right_motor = find_device_at_address(LargeMotor, brick, "outB")
```

## Low-level Attributes

The standard `ev3dev` files, which provide the low-level sensor and motor interfaces, are mapped to a special `io` property of each Julia device. For example, to read a motor's position, we can do:

```julia
position = right_motor.io.position()
```

and to write a command to that motor, we can do:

```julia
right_motor.io.command("stop")
```

These low-level attributes will automatically convert the data to an appropriate type, so `right_motor.io.position()` returns an `Int`, while `right_motor.io.commands()` returns a `Vector{ASCIIString}`.

## Higher-level Commands

`Ev3dev.jl` also provides a few higher-level commands that may help automate some boring tasks.

For example, instead of querying `num_values`, `decimals`, `value0`, `value1`, etc. for a sensor, you can instead just do:

```julia
v = scaled_values(ultrasound_sensor)
```

which returns a vector of values scaled by the appropriate power of 10 given by `decimals` (for more about the `ev3dev` sensor interface, see: [lego-sensor-class](http://www.ev3dev.org/docs/drivers/lego-sensor-class/))

Likewise, to run a motor at a given speed, with speed regulation turned on, you can do:

```julia
run_continuous(right_motor, 100)
```
