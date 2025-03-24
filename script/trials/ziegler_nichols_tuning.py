# Define the voltage-distance equation
import pandas as pd
import numpy as np

import csv
import re
import time
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

import pandas as pd
import numpy as np

def tune(csv_filename,k_u):
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
		T_u  = 1 / max_freq
		print(f'ultimate period: {T_u:.2f}')
		# P 
		a_p = 0.5 * k_u
		print(f'P controller: k_p = {a_p:.2f}')
		# PI
		b_p = 0.45 * k_u
		b_i = 0.54 * k_u / T_u
		print(f'PI controller: k_p = {b_p:.2f}, k_i = {b_i:.2f}')
		# PID 
		c_p = 0.6 * k_u
		c_i = 1.2 * k_u / T_u
		c_d = 0.075 * k_u * T_u
		print(f'PID controller: k_p = {c_p:.2f}, k_i = {c_i:.2f}, k_d = {c_d:.2f}')
		
	except Exception as e:
		print(f'Error finding max frequency: {e}')

def plot(csv_filename):
	try:
	    data = pd.read_csv(csv_filename)
	    plt.figure(figsize=(10, 8))

	    # Plot 1: Distance to Wall vs Time
	    plt.subplot(3, 1, 1)
	    plt.plot(data['Time (ms)'], data['Wall Distance (cm)'], marker='o', linestyle='-', color='b', label='Distance to Wall')
	    plt.plot(data['Time (ms)'], data['Setpoint (cm)'], marker='^', linestyle=':', color='g', label='Setpoint')
	    plt.xlabel('Time (ms)')
	    plt.ylabel('Distance (cm)')
	    plt.title('Distance to Wall vs Time')
	    plt.legend()
	    plt.grid(True)

	    # FFT of Wall Distance
	    plt.subplot(3, 1, 2)
	    distance_signal = data['Wall Distance (cm)'].values
	    fft_result = np.fft.fft(distance_signal)
	    freqs = np.fft.fftfreq(len(distance_signal), d=0.0313)  # Sampling interval (31.3 ms)
	    plt.plot(freqs[:len(freqs)//2], np.abs(fft_result[:len(fft_result)//2]), color='r', label='FFT Magnitude')
	    plt.xlabel('Frequency (Hz)')
	    plt.ylabel('Magnitude')
	    plt.title('FFT of Wall Distance')
	    plt.grid(True)
	    plt.legend()

	    plt.tight_layout()
	    plt.show()
	except Exception as e:
	    print(f'Error plotting data: {e}')
# Example usage
# plot('wall_follower_trial_ultimate_gain.csv')
tune('wall_follower_trial_ultimate_gain.csv',970)
#plot('p_controller_370_turn.csv')
plot('p_controller_470_turn.csv')
plot('p_controller_570_turn.csv')
#plot('wall_follower_trial_ultimate_gain.csv')
plot('pd_controller_570_150_turn.csv')
plot('pd_controller_570_300_turn.csv')


