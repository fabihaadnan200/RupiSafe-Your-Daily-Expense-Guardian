import firebase_admin
from firebase_admin import credentials, firestore





cred = credentials.Certificate("D:\\Rupisafe_fyp\\backend\\keys\\minal-6ede8-firebase-adminsdk-fbsvc-4d1671aa49.json")  
firebase_admin.initialize_app(cred)
db = firestore.client()
def get_price(item_name, category):
    docs = (
        db.collection("rupisafe_survival")
        .where("item_name", "==", item_name)
        .where("category", "==", category)
        .order_by("updated_at", direction=firestore.Query.DESCENDING)
        .limit(1)
        .stream()
    )

    for doc in docs:
        data = doc.to_dict()
        return data.get("price")  

    return None

db.collection("rupisafe_survival").add({
    "item_name": "Local milk",
    "category": "Groceries",
    "price": 180,
    "source": "api",
    "updated_at": firestore.SERVER_TIMESTAMP
})
if __name__ == "__main__":
    price = get_price("Local milk", "Groceries")
    print("Price:", price)
