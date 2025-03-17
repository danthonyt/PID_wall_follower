import serial
import csv
import re
import time
import matplotlib.pyplot as plt
import pandas as pd

# Open the serial port
ser = serial.Serial('/dev/ttyUSB0', baudrate=115200, bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE, timeout=1)

# Flush any existing input data
ser.reset_input_buffer()

# Open the CSV file for writing
with open('output.csv', mode='w', newline='') as csv_file:
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(['Angular Velocity (RPM)', 'Duty Cycle Offset', 'Error', 'Duty Cycle', 'Time (ms)'])  # CSV header with time column

    print('Reading from UART...')
    
    time_ms = 50  # Start time at 50ms
    
    try:
        while True:
            line = ser.readline()
            if not line:
                continue

            # Print the raw bytes to see what is coming in
            print(f'Raw bytes: {line}')

            try:
                # Decode with error handling
                line = line.decode('utf-8', errors='replace').strip()
                print(f'Decoded line: {line}')

                # Match four 8-digit hex numbers separated by commas
                match = re.fullmatch(r'([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8})', line)
                if match:
                    angular_velocity = int(match.group(1), 16)
                    duty_cycle_offset = int(match.group(2), 16)
                    error = int(match.group(3), 16)
                    duty_cycle = int(match.group(4), 16)

                    # Convert duty cycle offset to signed 32-bit
                    if duty_cycle_offset >= 0x80000000:
                        duty_cycle_offset -= 0x100000000

                    # Convert error to signed 32-bit
                    if error >= 0x80000000:
                        error -= 0x100000000

                    print(f'Received: {line} -> Angular Velocity (RPM): {angular_velocity}, Duty Cycle Offset: {duty_cycle_offset}, Error: {error}, Duty Cycle: {duty_cycle}')
                    csv_writer.writerow([angular_velocity, duty_cycle_offset, error, duty_cycle, time_ms])

                    # Increment the time by 50ms
                    time_ms += 50
            except Exception as e:
                print(f'Error decoding line: {e}')
    except KeyboardInterrupt:
        print('\nStopping...')
    finally:
        ser.close()

# Plotting the graph after data collection
try:
    data = pd.read_csv('output.csv')
    plt.figure(figsize=(10, 6))
    plt.plot(data['Time (ms)'], data['Angular Velocity (RPM)'], marker='o', linestyle='-', color='b', label='Angular Velocity (RPM)')
    plt.plot(data['Time (ms)'], data['Duty Cycle Offset'], marker='x', linestyle='--', color='r', label='Duty Cycle Offset')
    plt.plot(data['Time (ms)'], data['Error'], marker='^', linestyle=':', color='g', label='Error')
    plt.plot(data['Time (ms)'], data['Duty Cycle'], marker='s', linestyle='-.', color='m', label='Duty Cycle')
    plt.xlabel('Time (ms)')
    plt.ylabel('Values')
    plt.title('Angular Velocity, Duty Cycle Offset, Error, and Duty Cycle vs Time')
    plt.legend()
    plt.grid(True)
    plt.show()
except Exception as e:
    print(f'Error plotting data: {e}')
