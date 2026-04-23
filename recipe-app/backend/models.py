import json
import os

import boto3
from sqlalchemy import Column, DateTime, Integer, String, Text, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime, timezone


def get_database_url() -> str:
    secret_name = os.environ.get("DB_SECRET_NAME")
    region = os.environ.get("AWS_REGION", "us-east-1")

    if secret_name:
        client = boto3.client("secretsmanager", region_name=region)
        response = client.get_secret_value(SecretId=secret_name)
        s = json.loads(response["SecretString"])
        host = s.get("host", os.environ.get("DB_HOST", "localhost"))
        port = s.get("port", os.environ.get("DB_PORT", "5432"))
        dbname = s.get("dbname", os.environ.get("DB_NAME", "recipes"))
        username = s.get("username", os.environ.get("DB_USER", "postgres"))
        password = s.get("password", os.environ.get("DB_PASSWORD", ""))
        return f"postgresql://{username}:{password}@{host}:{port}/{dbname}"

    host = os.environ.get("DB_HOST", "localhost")
    port = os.environ.get("DB_PORT", "5432")
    dbname = os.environ.get("DB_NAME", "recipes")
    username = os.environ.get("DB_USER", "postgres")
    password = os.environ.get("DB_PASSWORD", "postgres")
    return f"postgresql://{username}:{password}@{host}:{port}/{dbname}"


DATABASE_URL = get_database_url()
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Recipe(Base):
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    ingredients = Column(Text, nullable=False)
    steps = Column(Text, nullable=False)
    s3_image_key = Column(String(512), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
