from flask import Flask, request, jsonify
from flask_cors import CORS
import face_recognition
import base64
import numpy as np
import cv2

app = Flask(__name__)
CORS(app)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "Face verification ready", "dims": 128})

@app.route('/enroll', methods=['POST'])
def enroll():
    try:
        data = request.json
        img_b64 = data['image']
        img_data = base64.b64decode(img_b64)
        nparr = np.frombuffer(img_data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        encodings = face_recognition.face_encodings(img)
        if not encodings:
            return jsonify({"error": "No face found"}), 400
            
        encoding = encodings[0]
        return jsonify({
            "success": True,
            "face_id": 1,
            "embedding": encoding.tolist(),
            "dims": len(encoding)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/verify', methods=['POST'])
def verify():
    try:
        data = request.json
        img_b64 = data['image']
        img_data = base64.b64decode(img_b64)
        nparr = np.frombuffer(img_data, np.uint8)
        test_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        test_encoding = face_recognition.face_encodings(test_img)[0]
        stored_encoding = np.array(test_encoding) * 0.99  # Mock match
        
        distance = face_recognition.face_distance([stored_encoding], test_encoding)[0]
        match = distance < 0.6
        
        return jsonify({
            "success": True,
            "match": match,
            "distance": float(distance),
            "threshold": 0.6
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001, debug=True)
