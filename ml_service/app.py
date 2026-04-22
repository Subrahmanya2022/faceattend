from flask import Flask, request, jsonify
from flask_cors import CORS
from deepface import DeepFace
import base64
import numpy as np
import cv2

app = Flask(__name__)
CORS(app)

MODEL = "Facenet512"

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "OK", "model": MODEL})

# ================= ENROLL =================
@app.route('/enroll', methods=['POST'])
def enroll():
    try:
        data = request.json
        img_b64 = data.get('image')

        if not img_b64:
            return jsonify({"error": "No image"}), 400

        # decode image
        img_data = base64.b64decode(img_b64.split(',')[-1])
        nparr = np.frombuffer(img_data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        # DeepFace embedding
        result = DeepFace.represent(
            img_path=img,
            model_name=MODEL,
            enforce_detection=False
        )

        embedding = result[0]["embedding"]

        print("✅ Embedding:", len(embedding))

        return jsonify({
            "success": True,
            "embedding": embedding,
            "dims": len(embedding),
            "model": MODEL
        })

    except Exception as e:
        print("❌ ERROR:", str(e))
        return jsonify({"error": str(e)}), 500


@app.route('/verify', methods=['POST'])
def verify():
    return enroll()


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001, debug=True)


# from flask import Flask, request, jsonify
# from flask_cors import CORS
# import base64
# import numpy as np
# import cv2
# import face_recognition

# app = Flask(__name__)
# CORS(app)

# @app.route('/health', methods=['GET'])
# def health():
#     return jsonify({"status": "OK"})

# # ================= ENROLL =================
# @app.route('/enroll', methods=['POST'])
# def enroll():
#     try:
#         data = request.json

#         # ✅ FIX: backend sends { image: ... }
#         img_b64 = data.get('image')

#         if not img_b64:
#             return jsonify({"error": "No image provided"}), 400

#         # decode base64
#         img_data = base64.b64decode(img_b64.split(',')[-1])
#         nparr = np.frombuffer(img_data, np.uint8)
#         img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

#         encodings = face_recognition.face_encodings(img)

#         if len(encodings) == 0:
#             return jsonify({"error": "No face found"}), 400

#         embedding = encodings[0]

#         print("✅ Embedding:", len(embedding))

#         return jsonify({
#             "success": True,
#             "embedding": embedding.tolist(),
#             "dims": len(embedding)
#         })

#     except Exception as e:
#         print("❌ ERROR:", str(e))
#         return jsonify({"error": str(e)}), 500


# # ================= VERIFY =================
# @app.route('/verify', methods=['POST'])
# def verify():
#     return enroll()  # reuse same logic


# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=8001, debug=True)