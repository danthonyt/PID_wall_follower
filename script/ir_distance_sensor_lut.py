import numpy as np

# Define the voltage-distance equation
def voltage_from_distance(d):
    return 21.9/d + 0.174  # Using V = 3.713/d + 0.065

# Generate LUT for distances from 10 cm to 80 cm in 1 cm steps
distances = np.arange(10, 80, 1)  # From 10 to 80 cm
voltages = [voltage_from_distance(d) for d in distances]

# Open a file to write the hex values
with open("adc_lookup.hex", "w") as hex_file:
    for v in voltages:
        adc_data = int((2**15 / 4.096) * v)  # Convert to integer ADC value
        hex_file.write(f"{adc_data:016X}\n")  # Write as 16-digit HEX

print("Hex file 'adc_lookup.hex' created successfully.")
