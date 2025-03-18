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
    csv_writer.writerow(['Distance (cm)', 'RPM Offset', 'Time (ms)'])  # CSV header with time column

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

                # Match two 8-digit hex numbers separated by a comma
                match = re.fullmatch(r'([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8})', line)
                if match:
                    distance_cm_measured = int(match.group(1), 16)
                    rpm_offset = int(match.group(2), 16)

                    # Convert rpm_offset to signed 32-bit
                    if rpm_offset >= 0x80000000:
                        rpm_offset -= 0x100000000

                    print(f'Received: {line} -> Distance (cm): {distance_cm_measured}, RPM Offset: {rpm_offset}')
                    csv_writer.writerow([distance_cm_measured, rpm_offset, time_ms])

                    # Increment the time by 50ms
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
    plt.plot(data['Time (ms)'], data['Distance (cm)'], marker='o', linestyle='-', color='b', label='Distance (cm)')
    plt.plot(data['Time (ms)'], data['RPM Offset'], marker='x', linestyle='--', color='r', label='RPM Offset')
    plt.xlabel('Time (ms)')
    plt.ylabel('Values')
    plt.title('Distance and RPM Offset vs Time')
    plt.legend()
    plt.grid(True)
    plt.show()
except Exception as e:
    print(f'Error plotting data: {e}')
