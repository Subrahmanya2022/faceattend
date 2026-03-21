from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from face_engine import FaceEngine
import uvicorn

app = FastAPI()
face_engine = FaceEngine()

class EnrollRequest(BaseModel):
    images: List[str]

@app.get("/health")
async def health():
    return {"status": "Face ML ready", "model": "Facenet512"}

@app.post("/enroll")
async def enroll(request: EnrollRequest):
    try:
        # Generate 512-dim embedding from first image (base64)
        embedding = face_engine.get_embedding(request.images[0])
        
        return {
            "embedding": embedding.tolist(),  # pgvector expects array
            "model": "Facenet512",
            "dims": len(embedding)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
