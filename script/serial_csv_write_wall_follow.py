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
with open('wall_follower_trial.csv', mode='w', newline='') as csv_file:
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(['Wall Distance (cm)', 'Setpoint (cm)', 'Time (ms)'])  # CSV header

    print('Reading from UART...')

    time_ms = 31.3  # Start time 1/32 seconds

    try:
        while True:
            line = ser.readline()
            if not line:
                continue

            print(f'Raw bytes: {line}')

            try:
                line = line.decode('utf-8', errors='replace').strip()
                print(f'Decoded line: {line}')

                match = re.fullmatch(r'([0-9A-Fa-f]{8}),([0-9A-Fa-f]{8})', line)
                if match:
                    distance_cm = int(match.group(1), 16)
                    setpoint = int(match.group(2), 16)
                    print(f'Received: {line} -> Wall Distance (cm): {distance_cm}, Setpoint (cm): {setpoint}')
                    csv_writer.writerow([distance_cm, setpoint, time_ms])

                    time_ms += 31.3 
            except Exception as e:
                print(f'Error decoding line: {e}')
    except KeyboardInterrupt:
        print('\nStopping...')
    finally:
        ser.close()

# Plotting the data after collection
try:
    data = pd.read_csv('wall_follower_trial.csv')
    plt.figure(figsize=(10, 6))

    # Plot 1: Distance to Wall vs Time
    plt.subplot(2, 1, 1)
    plt.plot(data['Time (ms)'], data['Wall Distance (cm)'], marker='o', linestyle='-', color='b', label='Distance to Wall')
    plt.plot(data['Time (ms)'], data['Setpoint'], marker='^', linestyle=':', color='g', label='Setpoint')
    plt.xlabel('Time (ms)')
    plt.ylabel('Distance (cm)')
    plt.title('Distance to Wall vs Time')
    plt.legend()
    plt.grid(True)

    plt.tight_layout()
    plt.show()
except Exception as e:
    print(f'Error plotting data: {e}')
