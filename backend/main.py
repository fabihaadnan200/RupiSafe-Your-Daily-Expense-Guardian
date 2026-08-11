from fastapi import FastAPI
from pydantic import BaseModel
from scraper import fetch_all_categories
from utils.survival import check_survival
import firebase_admin
from firebase_admin import credentials, firestore
import pickle, xgboost as xgb, numpy as np, re
from scipy.sparse import hstack, csr_matrix
import pandas as pd

# Firebase init
if not firebase_admin._apps:
    cred = credentials.Certificate(
        "D:\\Rupisafe_fyp\\backend\\keys\\minal-6ede8-firebase-adminsdk-fbsvc-4d1671aa49.json"
    )
    firebase_admin.initialize_app(cred)
db = firestore.client()

# FastAPI
app = FastAPI()

# Categories & item_map
categories = ["Groceries", "Beverages", "Dining", "Fitness", "Transport",
              "Travel", "Entertainment", "Education", "Hobbies", "Gifts",
              "Utilities", "Healthcare", "Shopping"]

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

# Load ML models
with open("model/xgb_classifier.pkl", "rb") as f: model = pickle.load(f)
with open("model/tfidf_vectorizer.pkl", "rb") as f: vectorizer = pickle.load(f)
with open("model/label_encoder.pkl", "rb") as f: le = pickle.load(f)
with open("D:\\rupisafe_fyp\\training\\numeric_scaler.pkl", "rb") as f: scaler = pickle.load(f)
with open("D:\\Rupisafe_fyp\\training\\payment_cols.pkl", "rb") as f: payment_cols = pickle.load(f)
with open("D:\\Rupisafe_fyp\\training\\location_cols.pkl", "rb") as f: location_cols = pickle.load(f)

# Expense model
class Expense(BaseModel):
    user_id: str
    text: str
    amount: float
    payment_method: str
    location: str
    category: str = None


def clean_text(text): 
    return re.sub(r'[^a-z0-9\s]', '', str(text).lower())

def prepare_features(expense_dict):
    # infer category from item_map
    inferred_item = None
    text = expense_dict.get("text", "")
    for key, val in item_map.items():
        if key.lower() in text.lower():
            inferred_item = val
            break
    pm = expense_dict.get("payment_method", "")
    loc = expense_dict.get("location", "")

    text_vec = vectorizer.transform([clean_text(f"{inferred_item or text} {pm} {loc}")])
    num_scaled = scaler.transform([[0, expense_dict.get("amount", 0)]])
    payment_vec = pd.DataFrame(0, index=[0], columns=payment_cols)
    if f"pay_{pm}" in payment_cols: payment_vec[f"pay_{pm}"] = 1
    location_vec = pd.DataFrame(0, index=[0], columns=location_cols)
    if f"loc_{loc}" in location_cols: location_vec[f"loc_{loc}"] = 1

    combined = hstack([text_vec, csr_matrix(num_scaled),
                        csr_matrix(payment_vec.values), csr_matrix(location_vec.values)])
    return xgb.DMatrix(combined)

def save_transaction(user_id, text, amount, category):
    db.collection("users").document(user_id).collection("transactions").document().set(
        {"text": text, "amount": amount, "category": category}
    )

# API endpoints
@app.get("/")
def root(): 
    return {"message": "RupiSafe API is running"}

@app.post("/predict_test")
def predict_test(expense: Expense):
    try:
        # First, check if the item exists in item_map (case-insensitive)
        category_from_map = None
        for key, val in item_map.items():
            if key.lower() in expense.text.lower():
                category_from_map = val
                break

        if category_from_map:
            category = category_from_map
        else:
            # If no match, use ML model
            features_dict = {
                "text": expense.text or "",
                "Price Per Unit": 0,
                "Total Spent": expense.amount or 0,
                "Payment Method": expense.payment_method or "",
                "Location": expense.location or ""
            }
            dmatrix = prepare_features(features_dict)
            pred_probs = model.predict(dmatrix)
            pred_class = np.argmax(pred_probs, axis=1)
            category = le.inverse_transform(pred_class)[0]

        # Save transaction in Firestore
        save_transaction(
            user_id=expense.user_id,
            text=expense.text,
            amount=expense.amount,
            category=category
        )

        # Check survival mode
        survival_mode, daily_allowance = check_survival(expense.user_id)

        return {
            "category": category,
            "survival_mode": survival_mode,
            "daily_allowance": daily_allowance,
            "message": "Transaction saved and category predicted successfully"
        }

    except Exception as e:
        return {"error": str(e), "message": "Prediction failed"}

@app.get("/survival_status/{user_id}")
def survival_status(user_id: str):
    survival_mode, daily_allowance = check_survival(user_id)
    return {"survival_mode": survival_mode, "daily_allowance": daily_allowance}

@app.post("/update_products")
def update_products():
    all_products = fetch_all_categories(categories)
    saved_count = 0
    for category, products in all_products.items():
        for p in products:
            db.collection("daraz_products").document().set({
                "category": category,
                "name": p["name"],
                "price": p["price"],
                "image": p["image"],
                "link": p["link"]
            })
            saved_count += 1
    return {"message": f"Saved {saved_count} products to Firestore"}

@app.get("/get_alternatives/{user_id}/{item_text}")
def get_alternatives(user_id: str, item_text: str):
   
    from get_alternatives import get_alternatives as fetch_alts
    alts = fetch_alts(item_text, user_id)
    return {"alternatives": alts}
