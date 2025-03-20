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
    csv_writer.writerow(['L Wheel Angular Velocity (RPM)', 'L Setpoint (RPM)', 'L Duty Cycle Offset', 'R Wheel Angular Velocity (RPM)', 'R Setpoint (RPM)','R Duty Cycle Offset', 'Time (ms)'])

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
                    l_wheel_rpm = int(match.group(1), 16)
                    l_setpoint = int(match.group(2), 16)
                    duty_cycle_l_offset = int(match.group(3), 16)
                    r_wheel_rpm = int(match.group(4), 16)
                    r_setpoint = int(match.group(5), 16)
                    duty_cycle_r_offset = int(match.group(6), 16)

                    if duty_cycle_l_offset & (1 << 31):
                        duty_cycle_l_offset -= (1 << 32)
                    if duty_cycle_r_offset & (1 << 31):
                        duty_cycle_r_offset -= (1 << 32)

                    print(f'Received: {line} -> L Wheel RPM: {l_wheel_rpm}, L Setpoint: {l_setpoint}, L Duty Cycle Offset: {duty_cycle_l_offset}, R Wheel RPM: {r_wheel_rpm}, R Setpoint: {r_setpoint}, R Duty Cycle Offset: {duty_cycle_r_offset}')
                    csv_writer.writerow([l_wheel_rpm, l_setpoint, duty_cycle_l_offset, r_wheel_rpm, r_setpoint, duty_cycle_r_offset, time_ms])

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
    plt.plot(data['Time (ms)'], data['L Wheel Angular Velocity (RPM)'], marker='o', linestyle='-', color='b', label='L Wheel Angular Velocity (RPM)')
    plt.plot(data['Time (ms)'], data['L Setpoint (RPM)'], marker='^', linestyle=':', color='g', label='L Setpoint (RPM)')
    plt.xlabel('Time (ms)')
    plt.ylabel('Angular Velocity (RPM)')
    plt.title('Left Wheel Angular Velocity (RPM) vs Time')
    plt.legend()
    plt.grid(True)
    plt.show()

    # Plotting Right Wheel Data
    plt.figure(figsize=(10, 6))
    plt.plot(data['Time (ms)'], data['R Wheel Angular Velocity (RPM)'], marker='x', linestyle='--', color='r', label='R Wheel Angular Velocity (RPM)')
    plt.plot(data['Time (ms)'], data['R Setpoint (RPM)'], marker='v', linestyle=':', color='c', label='R Setpoint (RPM)')
    
    plt.xlabel('Time (ms)')
    plt.ylabel('Angular Velocity (RPM)')
    plt.title('Right Wheel Angular Velocity (RPM) vs Time')
    plt.legend()
    plt.grid(True)
    plt.show()

    plt.figure(figsize=(10, 6))
    plt.plot(data['Time (ms)'], data['L Duty Cycle Offset'], marker='v', linestyle='-.', color='r', label='L Duty Cycle Offset')
    plt.plot(data['Time (ms)'], data['R Duty Cycle Offset'], marker='o', linestyle='-.', color='b', label='R Duty Cycle Offset')
    plt.xlabel('Time (ms)')
    plt.ylabel('Duty Cycle Offset')
    plt.title('Duty Cycle Offset vs Time')
    plt.legend()
    plt.grid(True)
    plt.show()

except Exception as e:
    print(f'Error plotting data: {e}')
