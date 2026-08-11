import pickle
import re
import numpy as np
from scipy.sparse import hstack, csr_matrix
import xgboost as xgb


clf = pickle.load(open("D:\\rupisafe_fyp\\training\\xgb_classifier.pkl", "rb"))
tfidf = pickle.load(open("D:\\rupisafe_fyp\\training\\tfidf_vectorizer.pkl", "rb"))
le = pickle.load(open("D:\\rupisafe_fyp\\training\\label_encoder.pkl", "rb"))
scaler = pickle.load(open("D:\\rupisafe_fyp\\training\\numeric_scaler.pkl", "rb"))
payment_cols = pickle.load(open("D:\\rupisafe_fyp\\training\\payment_cols.pkl", "rb"))
location_cols = pickle.load(open("D:\\rupisafe_fyp\\training\\location_cols.pkl", "rb"))


item_map = {
    'milk': 'Groceries', 'bread': 'Groceries', 'vegetables': 'Groceries', 'fruits': 'Groceries',
    'chicken': 'Groceries', 'snacks': 'Groceries', 'meat': 'Groceries',
    'toothpaste': 'Personal Care', 'shampoo': 'Personal Care', 'soap': 'Personal Care', 'skin care products': 'Personal Care',
    'coffee': 'Beverages',
    'fast food': 'Dining', 'dinner with friends': 'Dining', 'restaurant meal': 'Dining',
    'yoga class': 'Fitness', 'personal trainer': 'Fitness', 'workout equipment': 'Fitness', 'gym membership': 'Fitness',
    'car repair': 'Transport', 'gas': 'Transport', 'taxi/uber': 'Transport', 'public transit': 'Transport',
    'plane ticket': 'Travel', 'hotel stay': 'Travel',
    'concert tickets': 'Entertainment', 'streaming service': 'Entertainment', 'movie tickets': 'Entertainment',
    'video games': 'Entertainment', 'kids games': 'Entertainment',
    'books': 'Education', 'art supplies': 'Hobbies', 'crochet supplies': 'Hobbies', 'magazine': 'Hobbies',
    'gift cards': 'Gifts', 'jewelry': 'Gifts', 'flowers': 'Gifts',
    'water bill': 'Utilities', 'gas bill': 'Utilities', 'electricity bill': 'Utilities', 'rent': 'Utilities',
    'medicine': 'Healthcare', 'doctor visit': 'Healthcare', 'dentist visit': 'Healthcare',
    'car': 'Shopping', 'shoes': 'Shopping', 'Cloths': 'Shopping', 'electronics': 'Shopping',
}


def clean_text(text):
    text = str(text).lower()
    text = re.sub(r'[^a-z0-9\s]', '', text)
    return text

tx_items = [
    {"item": "Clothes", "payment": "Cash", "location": "Online", "price": 2000, "total": 2000},
    {"item": "Dentist Visit", "payment": "Cash", "location": "Offline", "price": 500, "total": 500},
    {"item": "Car", "payment": "Cash", "location": "Online", "price": 1000, "total": 1000},
    {"item": "milk", "payment": "Cash", "location": "Online", "price": 50, "total": 50},
    {"item": "bread", "payment": "Cash", "location": "Online", "price": 30, "total": 30},
    {"item": "books", "payment": "Cash", "location": "Online", "price": 500, "total": 500},
]

# Predict
for tx in tx_items:
   
    item_lower = tx['item'].lower()
    mapped_item = item_map.get(item_lower, tx['item'])
    
    # Text features
    tx_text = f"{mapped_item} {tx['payment']}"
    tx_text_clean = clean_text(tx_text)
    tx_tfidf = tfidf.transform([tx_text_clean])
    
    # Numeric features
    tx_num = np.array([[tx['price'], tx['total']]])
    tx_num_scaled = scaler.transform(tx_num)
    
    # Dummy categorical features
    pay_dummy = np.zeros((1, len(payment_cols)))
    loc_dummy = np.zeros((1, len(location_cols)))
    
    pay_col = f"pay_{tx['payment']}"
    loc_col = f"loc_{tx['location']}"
    if pay_col in payment_cols:
        pay_dummy[0, payment_cols.index(pay_col)] = 1
    if loc_col in location_cols:
        loc_dummy[0, location_cols.index(loc_col)] = 1
    
    # Combine all features
    tx_combined = hstack([tx_tfidf, tx_num_scaled, csr_matrix(pay_dummy), csr_matrix(loc_dummy)])
    
    # Predict
    tx_dmatrix = xgb.DMatrix(tx_combined)
    pred_class = np.argmax(clf.predict(tx_dmatrix), axis=1)
    
    # Output
    print(f"{tx['item']} -> {le.inverse_transform(pred_class)[0]}")
