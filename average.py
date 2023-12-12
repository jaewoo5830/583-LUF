import pandas as pd
import re
from collections import defaultdict

def parse_filename(filename):
    """Extract numerical characteristics from the filename, ignoring the last one."""
    tokens = re.split('_', filename)
    key = list()
    key.append(tokens[0])
    for i in range(1, len(tokens)):
        if tokens[i].isdigit():
            key.append(tokens[i])
        else: 
            break

    return '_'.join(key)

def process_file(file_path, output_file_path):
    # Read the CSV file into a Pandas DataFrame
    df = pd.read_csv(file_path, header=None)

    # Splitting the DataFrame into filename and run times
    filenames = df[0]
    run_times = df.drop(0, axis=1)

    # Grouping the run times by the parsed filename keys
    grouped_data = defaultdict(list)
    for filename, times in zip(filenames, run_times.values):
        key = parse_filename(filename)
        grouped_data[key].append(times)

    # Calculating averages for each group
    output = []
    for key, runs in grouped_data.items():
        avg_runs = pd.DataFrame(runs).mean().tolist()
        output.append([key, *avg_runs])

    output_df = pd.DataFrame(output)
    output_df.to_csv(output_file_path, index=False, header=False)

# Example usage
file_path = "label0.csv"  # Replace with your actual file path
output_file_path = "output.csv"
process_file(file_path, output_file_path)
