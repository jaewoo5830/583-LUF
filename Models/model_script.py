import argparse
import pandas as pd
import xgboost
from pickle import load


def predict_ideal_unroll_factor(filename, model):
    feature_df = pd.read_csv(filename)
    feature_df = feature_df.set_index("Filename")

    feature_cols = ['Depth', 'TripCount', 'Total', 'FP', 'BR', 'Mem', 'Uses', 'Defs']
    X = feature_df.loc[:, feature_cols].to_numpy()
    y_predicted = model.predict(X)
    if type(model).__name__ == 'XGBClassifier':
        return 2**y_predicted[0]
    else:
        return y_predicted[0]

parser = argparse.ArgumentParser()
parser.add_argument('filename', help='csv file with features')
parser.add_argument('model')
args = parser.parse_args()

pickle_file = open(args.model, 'rb')
model = load(pickle_file)

print(predict_ideal_unroll_factor(args.filename, model))
