import os
import uuid
from typing import Optional

import boto3
from botocore.exceptions import ClientError
from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from models import Base, Recipe, engine, get_db

app = FastAPI(title="Amma's Kitchen API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.environ.get("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

Base.metadata.create_all(bind=engine)

AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
S3_BUCKET = os.environ.get("S3_BUCKET_NAME", "")


def s3_client():
    return boto3.client("s3", region_name=AWS_REGION)


def presigned_url(key: str) -> Optional[str]:
    if not key or not S3_BUCKET:
        return None
    try:
        return s3_client().generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": key},
            ExpiresIn=3600,
        )
    except ClientError:
        return None


def recipe_to_dict(recipe: Recipe) -> dict:
    return {
        "id": recipe.id,
        "title": recipe.title,
        "ingredients": recipe.ingredients,
        "steps": recipe.steps,
        "image_url": presigned_url(recipe.s3_image_key),
        "created_at": recipe.created_at.isoformat(),
    }


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/recipes")
def list_recipes(db: Session = Depends(get_db)):
    recipes = db.query(Recipe).order_by(Recipe.created_at.desc()).all()
    return [recipe_to_dict(r) for r in recipes]


@app.get("/recipes/{recipe_id}")
def get_recipe(recipe_id: int, db: Session = Depends(get_db)):
    recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe_to_dict(recipe)


@app.post("/recipes", status_code=201)
async def create_recipe(
    title: str = Form(...),
    ingredients: str = Form(...),
    steps: str = Form(...),
    photo: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
):
    s3_image_key = None

    if photo and photo.filename and S3_BUCKET:
        ext = photo.filename.rsplit(".", 1)[-1].lower() if "." in photo.filename else "jpg"
        s3_image_key = f"recipes/{uuid.uuid4()}.{ext}"
        contents = await photo.read()
        try:
            s3_client().put_object(
                Bucket=S3_BUCKET,
                Key=s3_image_key,
                Body=contents,
                ContentType=photo.content_type or "image/jpeg",
            )
        except ClientError as exc:
            raise HTTPException(status_code=500, detail="Failed to upload image") from exc

    recipe = Recipe(title=title, ingredients=ingredients, steps=steps, s3_image_key=s3_image_key)
    db.add(recipe)
    db.commit()
    db.refresh(recipe)
    return recipe_to_dict(recipe)
