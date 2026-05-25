"""Export Olist tables from SQLite to CSV for Power BI."""
import sqlite3
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).parent.parent
DB = ROOT / "data" / "olist.sqlite" 
OUT = ROOT / "dashboard" / "data"
OUT.mkdir(parents=True, exist_ok=True)

TABLES = [
    "orders",
    "order_items",
    "order_reviews",
    "order_payments",
    "customers",
    "sellers",
    "products",
    "product_category_name_translation",
]

with sqlite3.connect(DB) as conn:
    for t in TABLES:
        df = pd.read_sql(f"SELECT * FROM {t}", conn)
        df.to_csv(OUT / f"{t}.csv", index=False)
        print(f"{t}: {len(df):,} rows")