import serial
import csv
import time

# Serial port configuration
PORT = '/dev/ttyUSB0'  # Change this to your serial port
BAUD_RATE = 115200       # Change to match your device's baud rate

# Open the serial port
try:
    ser = serial.Serial(PORT, BAUD_RATE, timeout=1)
    print(f'Connected to {PORT} at {BAUD_RATE} baud rate')
except serial.SerialException as e:
    print(f'Error opening serial port: {e}')
    exit(1)

# Open the CSV file for writing
with open('data.csv', 'w', newline='') as csvfile:
    csv_writer = csv.writer(csvfile)
    # Write the header
    csv_writer.writerow(['time', 'error', 'rpm'])

    try:
        while True:
            line = ser.readline().decode('utf-8').strip()
            if line:
                # Split the data assuming it is comma-separated
                data = line.split(',')
                if len(data) == 3:
                    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
                    csv_writer.writerow([timestamp, data[0], data[1], data[2]])
                    print(f'Logged: {timestamp}, {data[0]}, {data[1]}, {data[2]}')
    except KeyboardInterrupt:
        print('Logging stopped.')
    finally:
        ser.close()
        print('Serial port closed.')
