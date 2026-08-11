import pickle
import xgboost as xgb
import pandas as pd
import numpy as np
from scipy.sparse import hstack, csr_matrix
from utils.survival import check_survival
from firebase_admin import firestore

# Load models and encoders
with open("model/xgb_classifier.pkl", "rb") as f:
    bst = pickle.load(f)
with open("model/tfidf_vectorizer.pkl", "rb") as f:
    tfidf = pickle.load(f)
with open("model/label_encoder.pkl", "rb") as f:
    le = pickle.load(f)
with open("D:\\rupisafe_fyp\\training\\numeric_scaler.pkl", "rb") as f:
    scaler = pickle.load(f)
with open("D:\\rupisafe_fyp\\training\\payment_cols.pkl", "rb") as f:
    payment_cols = pickle.load(f)
with open("D:\\rupisafe_fyp\\training\\location_cols.pkl", "rb") as f:
    location_cols = pickle.load(f)

# Item map for quick category inference
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

def predict_category(item_text, price_per_unit=0, total_spent=0, payment_method='Cash', location='Home'):
    import re
    text = str(item_text).lower()
    text = re.sub(r'[^a-z0-9\s]', '', text)

    X_tfidf = tfidf.transform([text])
    X_num = scaler.transform([[price_per_unit, total_spent]])

    payment_dummy = pd.DataFrame(0, index=[0], columns=payment_cols)
    if f"pay_{payment_method}" in payment_dummy.columns:
        payment_dummy[f"pay_{payment_method}"] = 1
    location_dummy = pd.DataFrame(0, index=[0], columns=location_cols)
    if f"loc_{location}" in location_dummy.columns:
        location_dummy[f"loc_{location}"] = 1

    X_dummy = hstack([csr_matrix(payment_dummy.values), csr_matrix(location_dummy.values)])
    X_combined = hstack([X_tfidf, X_num, X_dummy])
    dmatrix = xgb.DMatrix(X_combined)

    y_pred_prob = bst.predict(dmatrix)
    y_pred_class = np.argmax(y_pred_prob, axis=1)[0]
    category = le.inverse_transform([y_pred_class])[0]
    return category

def get_alternatives(item_text, user_id):
    survival_mode, daily_allowance = check_survival(user_id)

    # Survival mode OFF or allowance 0 then return nothing
    if not survival_mode or daily_allowance <= 0:
        print(f"Survival mode OFF or allowance 0 for user {user_id}: no alternatives")
        return []

    # Try item_map first
    category = None
    for key, val in item_map.items():
        if key.lower() in item_text.lower():
            category = val
            break  # 

    # Fallback to ML prediction if no mapping found
    if not category:
        category = predict_category(item_text)

    # Fetch products from Firestore
    db = firestore.client()
    products_ref = db.collection("daraz_products").where("category", "==", category).stream()
    all_products = [doc.to_dict() for doc in products_ref]
    if not all_products:
        print(f"No products found in category '{category}'")
        return []

    # Filter by keyword match first
    keyword_filtered = [p for p in all_products if item_text.lower() in p.get("name", "").lower()]
    relevant_products = keyword_filtered  # no fallback
    if not relevant_products:
        print(f"No products found matching '{item_text}' in category '{category}'")
        return []


    # Filter by daily allowance
    cheaper_alts = []
    for p in relevant_products:
        try:
            price_val = float(p["price"]) if isinstance(p["price"], (int, float, str)) else 0
            if price_val <= daily_allowance:
                p["price"] = price_val
                cheaper_alts.append(p)
        except:
            continue

    # Sort by price and return top 5
    cheaper_alts.sort(key=lambda x: x["price"])
    return cheaper_alts[:5] if cheaper_alts else relevant_products[:5]


# Test run
if __name__ == "__main__":
    user_id = "55"
    item = "jewelry"
    alts = get_alternatives(item, user_id)
    print("Live alternatives:", alts)
