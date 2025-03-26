import serial
import csv
import re
import time
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from trials.ziegler_nichols_tuning import plot

def hex_to_signed_int(hex_str):
    value = int(hex_str, 16)
    if value >= 0x80000000:  # Convert from two's complement
        value -= 0x100000000
    return value

# Open the serial port
ser = serial.Serial('COM4', baudrate=115200, bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE, timeout=3)
ser.reset_input_buffer()

# Open CSV file for writing
csv_file = open('wall_follower_trial.csv', mode='w', newline='')
csv_writer = csv.writer(csv_file)
csv_writer.writerow(['Wall Distance (cm)', 'Setpoint (cm)', 'Error (cm)', 'Duty Cycle Offset', 'Time (ms)'])

print('Reading from UART...')

time_ms = 31.3  # Start time

try:
    while True:
        line = ser.readline()
        if not line:
            continue

        print(f'Raw bytes: {line}')

        try:
            line = line.decode('utf-8', errors='replace').strip()
            print(f'Decoded line: {line}')

            match = re.fullmatch(r'([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8})', line)
            if match:
                distance_cm = int(match.group(1), 16)
                setpoint = int(match.group(2), 16)
                error_cm = hex_to_signed_int(match.group(3))
                duty_cycle_offset = hex_to_signed_int(match.group(4))
                
                print(f'Received: {line} -> Wall Distance: {distance_cm} cm, Setpoint: {setpoint} cm, Error: {error_cm} cm, Duty Cycle Offset: {duty_cycle_offset}')
                csv_writer.writerow([distance_cm, setpoint, error_cm, duty_cycle_offset, time_ms])
                csv_file.flush()
                time_ms += 31.3
        except Exception as e:
            print(f'Error decoding line: {e}')
except KeyboardInterrupt:
    print('\nStopping...')
finally:
    ser.close()
    csv_file.close()
    time.sleep(0.5)

# Plotting the data after collection
plot('wall_follower_trial.csv')
