from pid_data_defs import tune
import os
directory = os.getcwd()  # Get the current working directory
tune(os.path.join(directory,"trials", "ultimate_gain_trial_1600.csv"), 1600)