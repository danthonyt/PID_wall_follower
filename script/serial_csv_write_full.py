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
    csv_writer.writerow(['L Wheel RPM', 'R Wheel RPM', 'Wall Distance (cm)', 'Time (ms)'])  # CSV header

    print('Reading from UART...')

    time_ms = 50  # Start time at 50ms

    try:
        while True:
            line = ser.readline()
            if not line:
                continue

            print(f'Raw bytes: {line}')

            try:
                line = line.decode('utf-8', errors='replace').strip()
                print(f'Decoded line: {line}')

                match = re.fullmatch(r'([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8})', line)
                if match:
                    l_rpm = int(match.group(1), 16)
                    r_rpm = int(match.group(2), 16)
                    distance_cm = int(match.group(3), 16)

                    if l_rpm >= 0x80000000:
                        l_rpm -= 0x100000000
                    if r_rpm >= 0x80000000:
                        r_rpm -= 0x100000000

                    print(f'Received: {line} -> L Wheel RPM: {l_rpm}, R Wheel RPM: {r_rpm}, Wall Distance (cm): {distance_cm}')
                    csv_writer.writerow([l_rpm, r_rpm, distance_cm, time_ms])

                    time_ms += 50
            except Exception as e:
                print(f'Error decoding line: {e}')
    except KeyboardInterrupt:
        print('\nStopping...')
    finally:
        ser.close()

# Plotting the data after collection
try:
    data = pd.read_csv('output.csv')
    plt.figure(figsize=(10, 6))

    # Plot 1: Distance to Wall vs Time
    plt.subplot(2, 1, 1)
    plt.plot(data['Time (ms)'], data['Wall Distance (cm)'], marker='o', linestyle='-', color='b', label='Distance to Wall')
    plt.axhline(y=20, color='r', linestyle='--', label='Setpoint (20 cm)')
    plt.xlabel('Time (ms)')
    plt.ylabel('Distance (cm)')
    plt.title('Distance to Wall vs Time')
    plt.legend()
    plt.grid(True)

    # Plot 2: Wheel RPMs vs Time
    plt.subplot(2, 1, 2)
    plt.plot(data['Time (ms)'], data['L Wheel RPM'], marker='x', linestyle='-', color='g', label='L Wheel RPM')
    plt.plot(data['Time (ms)'], data['R Wheel RPM'], marker='^', linestyle='--', color='m', label='R Wheel RPM')
    plt.xlabel('Time (ms)')
    plt.ylabel('RPM')
    plt.title('Wheel RPMs vs Time')
    plt.legend()
    plt.grid(True)

    plt.tight_layout()
    plt.show()
except Exception as e:
    print(f'Error plotting data: {e}')
