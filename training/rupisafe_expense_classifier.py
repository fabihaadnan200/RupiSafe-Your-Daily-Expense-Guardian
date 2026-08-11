import pandas as pd
import numpy as np
import re
import pickle
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import StandardScaler
from scipy.sparse import hstack, csr_matrix
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.preprocessing import LabelEncoder
import xgboost as xgb

# Load data
df = pd.read_csv("D:\\rupisafe_fyp\\dataset\\spending_patterns_detailed.csv")
# preprocessing
# Map items to categories
item_map = {
    # Groceries 
    'Milk': 'Groceries', 
    'Bread': 'Groceries', 'Vegetables': 'Groceries', 'Fruits': 'Groceries',
    'Chicken': 'Groceries', 'Snacks': 'Groceries', 'Meat': 'Groceries',
    # Personal Care
    'Toothpaste': 'Personal Care', 'Shampoo': 'Personal Care', 
    'Soap': 'Personal Care', 'Skin Care Products': 'Personal Care',
    # Beverages
    'Coffee': 'Beverages',
    # Dining
    'Fast Food': 'Dining', 'Dinner with Friends': 'Dining', 
    'Restaurant Meal': 'Dining',
    # Fitness
    'Yoga Class': 'Fitness', 'Personal Trainer': 'Fitness', 
    'Workout Equipment': 'Fitness', 'Gym Membership': 'Fitness',
    # Transport
    'Car Repair': 'Transport', 'Gas': 'Transport', 'Taxi/Uber': 'Transport', 
    'Public Transit': 'Transport',
    # Travel
    'Plane Ticket': 'Travel', 'Hotel Stay': 'Travel',
    # Entertainment
    'Concert Tickets': 'Entertainment', 'Streaming Service': 'Entertainment',
      'Movie Tickets': 'Entertainment', 
    'Video Games': 'Entertainment', 'Kids Games': 'Entertainment',
    # Education / Hobbies
    'Books': 'Education', 'Art Supplies': 'Hobbies', 'Crochet Supplies': 'Hobbies',
      'Magazine': 'Hobbies',
    # Gifts / Luxury
    'Gift Cards': 'Gifts', 'Jewelry': 'Gifts', 'Flowers': 'Gifts',
    # Utilities / Bills
    'Water Bill': 'Utilities', 'Gas Bill': 'Utilities', 'Electricity Bill': 'Utilities', 
    'Rent': 'Utilities',
    'Medicine': 'Healthcare', 'Doctor Visit': 'Healthcare', 'Dentist Visit': 'Healthcare',
    # Shopping
    'Car': 'Shopping', 'Shoes': 'Shopping', 'Cloths': 'Shopping', 'Electronics': 'Shopping',
}
df['Item'] = df['Item'].map(item_map).fillna(df['Item'])
# Text cleaning function
def clean_text(text):
    text = str(text).lower()
    text = re.sub(r'[^a-z0-9\s]', '', text)
    return text
# Combine text features
df['text'] = df['Item'].astype(str) + " " + df['Payment Method'].astype(str) + " " + df['Location'].astype(str)
df['text_clean'] = df['text'].apply(clean_text)

# Features and labels
X_text = df['text_clean']
y = df['Category']

# Label encode target (assigns numerical values to categories)
le = LabelEncoder()
y_enc = le.fit_transform(y)

# Split dataset
X_train_text, X_temp_text, y_train, y_temp = train_test_split(X_text, y_enc, test_size=0.3, random_state=42)
X_val_text, X_test_text, y_val, y_test = train_test_split(X_temp_text, y_temp, test_size=0.5, random_state=42)

# TF-IDF vectorizer
tfidf = TfidfVectorizer(max_features=5000, ngram_range=(1,2), stop_words='english')
X_train_tfidf = tfidf.fit_transform(X_train_text)
X_val_tfidf = tfidf.transform(X_val_text)
X_test_tfidf = tfidf.transform(X_test_text)

# Numeric features
scaler = StandardScaler()
numeric_cols = ['Price Per Unit', 'Total Spent']
X_train_num = scaler.fit_transform(df.loc[X_train_text.index, numeric_cols])
X_val_num = scaler.transform(df.loc[X_val_text.index, numeric_cols])
X_test_num = scaler.transform(df.loc[X_test_text.index, numeric_cols])

# One-hot encode categorical features
payment_dummies = pd.get_dummies(df['Payment Method'], prefix='pay')
location_dummies = pd.get_dummies(df['Location'], prefix='loc')
payment_cols = list(payment_dummies.columns)
location_cols = list(location_dummies.columns)

with open("D:\\rupisafe_fyp\\training\\payment_cols.pkl", "wb") as f:
    pickle.dump(payment_cols, f)
with open("D:\\rupisafe_fyp\\training\\location_cols.pkl", "wb") as f:
    pickle.dump(location_cols, f)
item_cols = [f"item_{k}" for k in item_map.keys()]
with open("D:\\rupisafe_fyp\\training\\item_cols.pkl", "wb") as f:
    pickle.dump(item_cols, f)
X_train_dummy = hstack([
    csr_matrix(payment_dummies.loc[X_train_text.index].values),
    csr_matrix(location_dummies.loc[X_train_text.index].values)
])
X_val_dummy = hstack([
    csr_matrix(payment_dummies.loc[X_val_text.index].values),
    csr_matrix(location_dummies.loc[X_val_text.index].values)
])
X_test_dummy = hstack([
    csr_matrix(payment_dummies.loc[X_test_text.index].values),
    csr_matrix(location_dummies.loc[X_test_text.index].values)
])

# Combine features
X_train_combined = hstack([X_train_tfidf, X_train_num, X_train_dummy])
X_val_combined = hstack([X_val_tfidf, X_val_num, X_val_dummy])
X_test_combined = hstack([X_test_tfidf, X_test_num, X_test_dummy])

# Convert to DMatrix for XGBoost
dtrain = xgb.DMatrix(X_train_combined, label=y_train)
dval = xgb.DMatrix(X_val_combined, label=y_val)
dtest = xgb.DMatrix(X_test_combined, label=y_test)

# XGBoost parameters
params = {
    'objective': 'multi:softprob', # (multi-class classification probability)
    'num_class': len(le.classes_), # (total unique categories)
    'eval_metric': 'mlogloss', # (probabilities error for val / train)
    'learning_rate': 0.1, # (contribution of every tree)
    'max_depth': 6, # (tree depth)
    'subsample': 0.8, # (every tree uses 80% data randomly, reduces overfitting)
    'colsample_bytree': 0.8, # (every tree uses 80% features randomly, reduces overfitting)
    'seed': 42 # (Randomness fix)
}

evallist = [(dtrain, 'train'), (dval, 'val')]

# Training
bst = xgb.train(params, dtrain, num_boost_round=100, evals=evallist, early_stopping_rounds=10, verbose_eval=10)

# Predictions
y_train_pred = np.argmax(bst.predict(dtrain), axis=1)
y_val_pred = np.argmax(bst.predict(dval), axis=1)
y_test_pred = np.argmax(bst.predict(dtest), axis=1)

# Accuracy
print(f"Training Accuracy: {accuracy_score(y_train, y_train_pred)*100:.2f}%")
print(f"Validation Accuracy: {accuracy_score(y_val, y_val_pred)*100:.2f}%")
print(f"Test Accuracy: {accuracy_score(y_test, y_test_pred)*100:.2f}%")

# Classification report
print("\nTest Classification Report:\n", classification_report(y_test, y_test_pred, target_names=le.classes_))

# Confusion Matrix
def plot_cm(y_true, y_pred, labels, title, save_path=None):
    cm = confusion_matrix(y_true, y_pred, labels=range(len(labels)))
    plt.figure(figsize=(8,6))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=labels, yticklabels=labels)
    plt.xlabel('Predicted')
    plt.ylabel('Actual')
    plt.title(title)
    if save_path:
        plt.savefig(save_path, bbox_inches='tight')
    plt.show()

    
plot_cm(y_val, y_val_pred, le.classes_, 'Validation Set Confusion Matrix', 'D:\\rupisafe_fyp\\training\\val_cm.png')
plot_cm(y_test, y_test_pred, le.classes_, 'Test Set Confusion Matrix', 'D:\\rupisafe_fyp\\training\\test_cm.png')


# Feature importance
importance = bst.get_score(importance_type='weight')
feat_names = list(tfidf.get_feature_names_out()) + numeric_cols + list(payment_dummies.columns) + list(location_dummies.columns)
importance_df = pd.DataFrame({
    'feature': [feat_names[int(k[1:])] if k.startswith('f') else k for k in importance.keys()],
    'importance': importance.values()
}).sort_values(by='importance', ascending=False).head(20)

plt.figure(figsize=(8,6))
sns.barplot(x='importance', y='feature', data=importance_df, palette='viridis')
plt.title("Top 20 Important Features")
plt.show()
print("X_train_combined shape:", X_train_combined.shape)
print("Booster expects features:", bst.num_features())

# Save model, TF-IDF, label encoder
with open("D:\\rupisafe_fyp\\training\\xgb_classifier.pkl", 'wb') as f:
    pickle.dump(bst, f)
with open("D:\\rupisafe_fyp\\training\\tfidf_vectorizer.pkl", 'wb') as f:
    pickle.dump(tfidf, f)
with open("D:\\rupisafe_fyp\\training\\label_encoder.pkl", 'wb') as f:
    pickle.dump(le, f)
with open("D:\\rupisafe_fyp\\training\\numeric_scaler.pkl", "wb") as f:
    pickle.dump(scaler, f)
print("Model, TF-IDF vectorizer, and Label Encoder saved successfully.")
