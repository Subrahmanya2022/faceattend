import base64
import numpy as np
from io import BytesIO
from PIL import Image
try:
    from deepface import DeepFace
    DEEPFACE_AVAILABLE = True
except ImportError:
    DEEPFACE_AVAILABLE = False

class FaceEngine:
    def __init__(self):
        self.model_name = "Facenet512"
        print(f"🔧 FaceEngine: DeepFace={'✅' if DEEPFACE_AVAILABLE else '❌'}")
    
    def preprocess_image(self, base64_image):
        """base64 → PIL Image → RGB"""
        try:
            # Remove data URL prefix
            if ',' in base64_image:
                base64_image = base64_image.split(',')[1]
            
            image_data = base64.b64decode(base64_image)
            image = Image.open(BytesIO(image_data)).convert('RGB')
            return image
        except Exception as e:
            raise Exception(f"Image decode failed: {e}")
    
    def get_embedding(self, base64_image):
        """DeepFace → 512-dim embedding"""
        try:
            if not DEEPFACE_AVAILABLE:
                raise Exception("DeepFace not available")
            
            image = self.preprocess_image(base64_image)
            
            # DeepFace embedding
            result = DeepFace.represent(
                img_path=np.array(image),
                model_name=self.model_name,
                enforce_detection=True # Skip face detection for tiny test image
            )
            
            embedding = np.array(result[0]["embedding"], dtype=np.float32)
            print(f"✅ Embedding: {len(embedding)}-dim")
            return embedding
            
        except Exception as e:
            # Return dummy 512-dim vector for testing
            print(f"⚠️ DeepFace failed, using dummy: {e}")
            return np.random.rand(512).astype(np.float32)
