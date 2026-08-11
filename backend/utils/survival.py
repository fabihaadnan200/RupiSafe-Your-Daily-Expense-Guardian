from firebase_admin import firestore
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
import joblib
import os
import firebase_admin
from firebase_admin import credentials

# Firebase init
if not firebase_admin._apps:
    cred = credentials.Certificate("D:\\Rupisafe_fyp\\backend\\keys\\minal-6ede8-firebase-adminsdk-fbsvc-4d1671aa49.json")
    firebase_admin.initialize_app(cred)

db = firestore.client()

MODEL_FILE = "model/survival_model.pkl"
BUDGET = 50000
DAILY_ALLOWANCE = 1000

def check_survival(user_id):
    transactions_ref = db.collection("users").document(user_id).collection("transactions")
    docs = transactions_ref.stream()

    data = []
    for doc in docs:
        item = doc.to_dict()
        data.append({
            "user_id": user_id,
            "amount": item.get("amount", 0),
            "category": item.get("category", "")
        })

    df = pd.DataFrame(data)

    if df.empty:
        print("No transaction history for user → survival OFF")
        return False, 0

    total_spent = df["amount"].sum()
    spent_percent = (total_spent / BUDGET) * 100

    # Basic survival trigger rules
    survival_mode = False
    if spent_percent > 80:         # spent > 80% of budget
        survival_mode = True
    elif len(df) > 20:             # too many transactions
        survival_mode = True
    elif df["amount"].max() > 5000: # any big transaction
        survival_mode = True

    # ML fallback (only if enough data)
    if len(df) > 10 and os.path.exists(MODEL_FILE):
        user_features = pd.DataFrame([{
            "total_spent": total_spent,
            "max_spent": df["amount"].max(),
            "avg_spent": df["amount"].mean(),
            "transaction_count": len(df)
        }])
        model, scaler = joblib.load(MODEL_FILE)
        X_scaled = scaler.transform(user_features)
        survival_ml = bool(model.predict(X_scaled)[0])
        survival_mode = survival_mode or survival_ml

    # Final budget check: if total spent < 80%, ignore ML and other triggers
    if total_spent < 0.8 * BUDGET:
        survival_mode = False

    allowance = DAILY_ALLOWANCE if survival_mode else 0
    return survival_mode, allowance
