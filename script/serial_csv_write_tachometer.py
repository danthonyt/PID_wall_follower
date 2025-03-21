import serial
import csv
import re
import time
import matplotlib.pyplot as plt
import pandas as pd

# Open the serial port
ser = serial.Serial('/dev/ttyUSB1', baudrate=115200, bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE, timeout=1)

# Flush any existing input data
ser.reset_input_buffer()

# Open the CSV file for writing
with open('tachometer_trial.csv', mode='w', newline='') as csv_file:
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(['L Wheel Tachometer Count', 'L Tachometer Count Setpoint', 'L Tachometer Count Error', 'R Wheel Tachometer Count', 'R Tachometer Count Setpoint', 'R Tachometer Count Error', 'Time (ms)'])

    print('Reading from UART...')
    
    time_ms = 10  # Start time at 10ms
    
    try:
        while True:
            line = ser.readline()
            if not line:
                continue

            print(f'Raw bytes: {line}')

            try:
                line = line.decode('utf-8', errors='replace').strip()
                print(f'Decoded line: {line}')

                # Match six 8-digit hex numbers separated by commas
                match = re.fullmatch(r'([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8})', line)
                if match:
                    l_tach_count = int(match.group(1), 16)
                    l_tach_count_setpoint = int(match.group(2), 16)
                    l_tach_count_error = int(match.group(3), 16)
                    r_tach_count = int(match.group(4), 16)
                    r_tach_count_setpoint = int(match.group(5), 16)
                    r_tach_count_error = int(match.group(6), 16)
                    if l_tach_count_error >=   0x80000000:  # If the value is negative
                        l_tach_count_error -= 0x100000000

                    if r_tach_count_error >= 0x80000000:  # If the value is negative
                        r_tach_count_error -= 0x100000000

                    print(f'Received: {line} -> L Wheel Tach Count: {l_tach_count}, L Setpoint: {l_tach_count_setpoint}, L Error: {l_tach_count_error}, R Wheel Tach Count: {r_tach_count}, R Setpoint: {r_tach_count_setpoint}, R Error: {r_tach_count_error}')
                    csv_writer.writerow([l_tach_count, l_tach_count_setpoint, l_tach_count_error, r_tach_count, r_tach_count_setpoint, r_tach_count_error, time_ms])

                    # Increment the time by 10 ms
                    time_ms += 10
            except Exception as e:
                print(f'Error decoding line: {e}')
    except KeyboardInterrupt:
        print('\nStopping...')
    finally:
        ser.close()

# Plotting the left and right wheel data in separate graphs
try:
    data = pd.read_csv('tachometer_trial.csv')

    # Plotting Left Wheel Data
    plt.figure(figsize=(10, 6))
    plt.plot(data['Time (ms)'], data['L Wheel Tachometer Count'], marker='o', linestyle='-', color='b', label='L Wheel Tachometer Count')
    plt.plot(data['Time (ms)'], data['L Tachometer Count Setpoint'], marker='^', linestyle=':', color='g', label='L Setpoint')
    plt.xlabel('Time (ms)')
    plt.ylabel('Tachometer Count')
    plt.title('Left Wheel Tachometer Count vs Time')
    plt.legend()
    plt.grid(True)
    plt.show()

    # Plotting Right Wheel Data
    plt.figure(figsize=(10, 6))
    plt.plot(data['Time (ms)'], data['R Wheel Tachometer Count'], marker='x', linestyle='--', color='r', label='R Wheel Tachometer Count')
    plt.plot(data['Time (ms)'], data['R Tachometer Count Setpoint'], marker='v', linestyle=':', color='c', label='R Setpoint')
    plt.xlabel('Time (ms)')
    plt.ylabel('Tachometer Count')
    plt.title('Right Wheel Tachometer Count vs Time')
    plt.legend()
    plt.grid(True)
    plt.show()

    plt.figure(figsize=(10, 6))
    plt.plot(data['Time (ms)'], data['L Tachometer Count Error'], marker='v', linestyle='-.', color='r', label='L Tachometer Count Error')
    plt.plot(data['Time (ms)'], data['R Tachometer Count Error'], marker='o', linestyle='-.', color='b', label='R Tachometer Count Error')
    plt.xlabel('Time (ms)')
    plt.ylabel('Tachometer Count Error')
    plt.title('Tachometer Count Error vs Time')
    plt.legend()
    plt.grid(True)
    plt.show()

except Exception as e:
    print(f'Error plotting data: {e}')
