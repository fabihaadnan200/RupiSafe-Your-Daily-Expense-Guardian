from main import prepare_features, model, le

features_dict = {
    "text": "car",
    "Price Per Unit": 100000,
    "Total Spent": 100000,
    "Payment Method": "Credit Card",
    "Location": "Online"
}

try:
    dmatrix = prepare_features(features_dict)
    pred_probs = model.predict(dmatrix)
    pred_class = pred_probs.argmax(axis=1)
    category = le.inverse_transform(pred_class)[0]
    print("Predicted category:", category)
except Exception as e:
    print("Error:", e)
