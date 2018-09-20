#!/bin/sh

# Version 0.1

# This script implements a basic temperature-based fan-control algorithm

dir1="/sys/bus/i2c/devices/8-006c/hwmon/hw*"

# Temperature values
temp[1]=$(cat $dir1"/temp1_input")
temp[2]=$(cat $dir1"/temp2_input")
temp[3]=$(cat $dir1"/temp3_input")
temp[4]=$(cat $dir1"/temp4_input")

# Find the current maximum temperature reading on the board
max=0
for i in "${temp[@]}"
do
    if [ $i -gt $max ]; then
        max=$i
    fi
done

# The algorithm decides the fan speed based on the following temp ranges:
# 0 (error case) : 100% duty cycle (max speed - default setting)
# 1 to 14999     : 25% duty cycle
# 15000 to 29999 : 50% duty cycle
# 30000 to 44999 : 75% duty cycle
# Above 45000    : 100% dudty cycle (max speed)
# Note that temperature readings are inetrpreted as (value/1000) deg C
# i.e. A temperature reading of 15000 corresponds to 15 deg C
temp_limit1=15000
temp_limit2=30000
temp_limit3=45000
duty_cycle_25=63
duty_cycle_50=127
duty_cycle_75=191
duty_cycle_100=255
if [ $max -eq 0 ]; then
    pwm=$duty_cycle_100
elif [ $max -lt $temp_limit1 ]; then
    pwm=$duty_cycle_25
elif [ $max -lt $temp_limit2 ]; then
    pwm=$duty_cycle_50
elif [ $max -lt $temp_limit3 ]; then
    pwm=$duty_cycle_75
else
    pwm=$duty_cycle_100
fi

dir2="/sys/bus/i2c/devices/13-002f/hwmon/"
dir3=$(ls $dir2)
pwm_curr=$(cat $dir2$dir3"/pwm1")

change_fan_speed() {
    echo $pwm > $dir2$dir3"/pwm1"
    echo $pwm > $dir2$dir3"/pwm2"
    echo $pwm > $dir2$dir3"/pwm3"
    echo $pwm > $dir2$dir3"/pwm4"
}

if [ $pwm -gt $pwm_curr ]; then
    echo "Mellanox Fan Controller: Increasing Fan Speed"
    change_fan_speed
elif [ $pwm -lt $pwm_curr ]; then
    echo "Mellanox Fan Controller: Decreasing Fan Speed"
    change_fan_speed
fi
