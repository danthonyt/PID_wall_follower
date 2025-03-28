import pid_data_defs
import os

directory = os.getcwd()  # Get the current working directory
pid_data_defs.plot_all_csv(os.path.join(directory,"trials"))