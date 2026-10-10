import os
import tempfile

from faster_whisper import WhisperModel
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = int(os.getenv("MAX_UPLOAD_MB", "100")) * 1024 * 1024

allowed_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "*").split(",")
    if origin.strip()
]
CORS(app, resources={r"/*": {"origins": allowed_origins}})

_model = None


def get_model():
    global _model
    if _model is None:
        _model = WhisperModel(
            os.getenv("WHISPER_MODEL", "tiny"),
            device="cpu",
            compute_type="int8",
            cpu_threads=1,
        )
    return _model


def extract_keywords(text):
    fillers = {"um", "uh", "hmm", "like", "you", "know", "ok", "okay", "the", "and"}
    words = []
    for word in text.lower().split():
        clean = word.strip(".,!?;:\"'()[]{}")
        if len(clean) > 2 and clean not in fillers and clean not in words:
            words.append(clean)
    return words[:10]


@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "Boli speech analysis"})


@app.post("/upload")
def upload():
    uploaded = request.files.get("file")
    if uploaded is None or not uploaded.filename:
        return jsonify({"error": "Choose a video file to analyze."}), 400

    suffix = os.path.splitext(uploaded.filename)[1] or ".video"
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temporary_file:
            temporary_path = temporary_file.name
            uploaded.save(temporary_file)

        segments, _info = get_model().transcribe(temporary_path, beam_size=1)
        transcript = " ".join(segment.text.strip() for segment in segments).strip()
        return jsonify({"transcript": transcript, "keywords": extract_keywords(transcript)})
    except Exception:
        app.logger.exception("Video transcription failed")
        return jsonify({"error": "Video analysis failed. Try a smaller video or try again shortly."}), 500
    finally:
        if temporary_path and os.path.exists(temporary_path):
            os.remove(temporary_path)


@app.errorhandler(413)
def upload_too_large(_error):
    return jsonify({"error": "Video is too large. The maximum upload size is 100 MB."}), 413
