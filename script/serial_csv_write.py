import serial
import csv
import re
import time
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import os
from pid_data_defs import plot

def hex_to_signed_int(hex_str):
    value = int(hex_str, 16)
    if value >= 0x80000000:  # Convert from two's complement
        value -= 0x100000000
    return value

# Open the serial port
#ser = serial.Serial('/dev/ttyUSB0', baudrate=115200, bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE, timeout=3)
ser = serial.Serial('COM4', baudrate=115200, bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE, timeout=3)
ser.reset_input_buffer()

# Open CSV file for writing
csv_file = open('wall_follower_trial.csv', mode='w', newline='')
csv_writer = csv.writer(csv_file)
csv_writer.writerow(['Wall Distance (cm)', 'Setpoint (cm)', 'Error (cm)', 'Duty Cycle Offset', 'Proportional Term', 'Integral Term', 'Derivative Term', 'Time (ms)'])

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

            # Updated regex to match the new FIFO configuration (7 fields)
            match = re.fullmatch(
                r'([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),'
                r'([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8})', line
            )
            if match:
                distance_diag = int(match.group(1), 16)
                distance_diag_setpoint = int(match.group(2), 16)
                distance_error = hex_to_signed_int(match.group(3))
                p_term = hex_to_signed_int(match.group(4))
                i_term = hex_to_signed_int(match.group(5))
                d_term = hex_to_signed_int(match.group(6))
                duty_cycle_offset = hex_to_signed_int(match.group(7))

                print(f'Received: {line} -> '
                      f'Wall Distance: {distance_diag} cm, '
                      f'Setpoint: {distance_diag_setpoint} cm, '
                      f'Error: {distance_error} cm, '
                      f'Duty Cycle Offset: {duty_cycle_offset}, '
                      f'P-Term: {p_term}, '
                      f'I-Term: {i_term}, '
                      f'D-Term: {d_term}')

                # Write data to CSV
                csv_writer.writerow([distance_diag, distance_diag_setpoint, distance_error, duty_cycle_offset, p_term, i_term, d_term, time_ms])
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
directory = os.getcwd()  # Get the current working directory
plot('wall_follower_trial.csv',directory)
