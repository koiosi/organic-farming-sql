import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
SRC = Path(os.environ["DATA_DIR"])
engine = create_engine(os.environ["DATABASE_URL"])

with engine.begin() as conn:
    # full rebuild: views in mart depend on stg, so drop both first
    conn.execute(text("DROP SCHEMA IF EXISTS mart CASCADE"))
    conn.execute(text("DROP SCHEMA IF EXISTS stg CASCADE"))
    conn.execute(text("CREATE SCHEMA stg"))

for csv in sorted(SRC.glob("*.csv")):
    # all columns as text; only the literal "NA" becomes NULL
    df = pd.read_csv(csv, dtype=str, na_values=["NA"], keep_default_na=False)
    df.to_sql(csv.stem, engine, schema="stg", if_exists="replace", index=False)
    print(f"stg.{csv.stem}: {len(df)} rows")
