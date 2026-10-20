import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
load_dotenv()
engine = create_engine(os.environ["DATABASE_URL"])
with engine.connect() as conn:
    print(conn.execute(text("select current_database(), now()")).fetchone())
