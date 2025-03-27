import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

def tune(csv_filename, k_u):
	try:
	    data = pd.read_csv(csv_filename)
	    distance_signal = data['Wall Distance (cm)'].values

	    # Perform FFT
	    fft_result = np.fft.fft(distance_signal)
	    freqs = np.fft.fftfreq(len(distance_signal), d=0.0313)  # Sampling interval (31.3 ms)

	    # Keep only positive frequencies greater than 0.25 Hz
	    positive_freqs = freqs[1:len(freqs)//2]
	    positive_magnitudes = np.abs(fft_result[1:len(fft_result)//2])

	    # Filter out frequencies less than or equal to 0.25 Hz
	    valid_indices = np.where(positive_freqs > 0.25)
	    filtered_freqs = positive_freqs[valid_indices]
	    filtered_magnitudes = positive_magnitudes[valid_indices]

	    # Find the frequency with the highest magnitude
	    max_index = np.argmax(filtered_magnitudes)
	    max_freq = filtered_freqs[max_index]
	    max_magnitude = filtered_magnitudes[max_index]

	    print(f'Highest positive frequency > 0.25 Hz: {max_freq:.2f} Hz with amplitude {max_magnitude:.2f}')
	    T_u = 1 / max_freq
	    print(f'Ultimate period: {T_u:.2f}')

	    # PID Controller
	    c_p = 0.6 * k_u
	    c_i = 1.2 * k_u / T_u
	    c_d = 0.075 * k_u * T_u
	    print(f'PID controller: k_p = {c_p:.2f}, k_i = {c_i:.2f}, k_d = {c_d:.2f}')
	except Exception as e:
	    print(f'Error finding max frequency: {e}')

def plot(csv_filename,output_dir):
	try:
		# Read data from CSV
		data = pd.read_csv(csv_filename)

		# Create a figure with 4 subplots
		plt.figure(figsize=(10, 12))

		# Distance vs Time
		plt.subplot(4, 1, 1)
		plt.plot(data['Time (ms)'], data['Wall Distance (cm)'], marker='o', linestyle='-', color='b', label='Wall Distance')
		plt.plot(data['Time (ms)'], data['Setpoint (cm)'], marker='^', linestyle=':', color='g', label='Setpoint')
		plt.xlabel('Time (ms)')
		plt.ylabel('Distance (cm)')
		plt.title('Wall Distance vs Setpoint')
		plt.legend()
		plt.grid(True)

		# Proportional Term vs Time
		plt.subplot(4, 1, 2)
		plt.plot(data['Time (ms)'], data['Proportional Term'], marker='o', linestyle='-', color='orange', label='Proportional Term')
		plt.xlabel('Time (ms)')
		plt.ylabel('Proportional Term')
		plt.title('Proportional Term vs Time')
		plt.legend()
		plt.grid(True)

		# Integral Term vs Time
		plt.subplot(4, 1, 3)
		plt.plot(data['Time (ms)'], data['Integral Term'], marker='^', linestyle='-', color='blue', label='Integral Term')
		plt.xlabel('Time (ms)')
		plt.ylabel('Integral Term')
		plt.title('Integral Term vs Time')
		plt.legend()
		plt.grid(True)

		# Derivative Term vs Time
		plt.subplot(4, 1, 4)
		plt.plot(data['Time (ms)'], data['Derivative Term'], marker='x', linestyle='-', color='green', label='Derivative Term')
		plt.xlabel('Time (ms)')
		plt.ylabel('Derivative Term')
		plt.title('Derivative Term vs Time')
		plt.legend()
		plt.grid(True)

		# Adjust layout to prevent overlap
		plt.tight_layout()

		# Generate output file path
		filename = os.path.splitext(os.path.basename(csv_filename))[0]  # Get filename without extension
		output_path = os.path.join(output_dir, f"{filename}.png")

		# Save plot as PNG
		plt.savefig(output_path)
		plt.close()  # Close the figure to prevent memory leaks

		print(f"Saved plot: {output_path}")
	except Exception as e:
	    print(f'Error plotting data: {e}')


def plot_all_csv(directory):
    csv_files = [f for f in os.listdir(directory) if f.endswith('.csv')]

    if not csv_files:
        print("No CSV files found in the directory.")
        return

    for csv_file in csv_files:
        print(f"Processing: {csv_file}")
        plot(os.path.join(directory, csv_file),directory)

# Example usage
directory = os.getcwd()  # Get the current working directory
#plot_all_csv(os.path.join(directory,"trials"))
#tune(os.path.join(directory,"trials", "ultimate_gain_trial_1600.csv"), 1600)
