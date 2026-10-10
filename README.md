# Boli — AI Smart Speech Analysis

Boli detects speech and extracts useful keywords from live microphone input or uploaded videos.

**[Open the live demo](https://prasanna-rvssl.github.io/Boli-AI-Smart-Speech-Analysis/)**

## What it does

- **Live detection:** Uses browser speech recognition to show speech keywords in real time, with a camera preview. Microphone and camera access are requested by the browser when you use this feature.
- **Video analysis:** Upload a video to transcribe its speech with the `faster-whisper` tiny model and extract up to ten keywords.
- **Simple results:** Filters common filler words and displays the recognized keywords.

Video analysis sends the selected file to the Boli API on Render. The API processes it in a temporary file and removes that file after the request. The upload limit is 100 MB. On Render's free plan, the first request after inactivity can take longer while the service wakes and downloads the model.

## How it is built

| Part | Technology | Hosting |
| --- | --- | --- |
| Web app | Flutter and Dart | [GitHub Pages](https://prasanna-rvssl.github.io/Boli-AI-Smart-Speech-Analysis/) |
| Live speech recognition | Browser speech recognition | Visitor's browser |
| Video transcription API | Flask, faster-whisper, CTranslate2 | Render |

## Run locally

Requirements: Flutter SDK and Python 3.11.

Start the API in one terminal:

```powershell
cd backend
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
$env:WHISPER_MODEL = "tiny"
$env:MAX_UPLOAD_MB = "100"
python -m flask --app api run --host 127.0.0.1 --port 5000
```

Start the Flutter web app in another terminal:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

The microphone feature requires browser support for speech recognition; Chrome and Edge are recommended. Localhost and the deployed site use HTTPS-capable browser contexts for microphone access.

## Deployment

- The Render API Blueprint is defined in [`render.yaml`](render.yaml).
- GitHub Pages is built by [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml).
- The Pages workflow reads the repository Actions variable `API_BASE_URL` to configure the API endpoint.

See [`DEPLOYMENT.md`](DEPLOYMENT.md) for setup and hosting notes.

## Screenshots

### Home

<img width="1088" height="558" alt="Boli home screen" src="https://github.com/user-attachments/assets/b10bc1f1-6d6c-4ace-a4c4-2738477032e8" />

### Live detection

<img width="876" height="720" alt="Live speech detection" src="https://github.com/user-attachments/assets/1f0a4fdf-991e-4978-98b8-6482bb915779" />

<img width="1180" height="362" alt="Live keyword results" src="https://github.com/user-attachments/assets/fd4cbc18-7d2b-42c4-be60-f418de5bfb17" />

### Video upload and results

<img width="544" height="383" alt="Video upload" src="https://github.com/user-attachments/assets/77a4a729-90bf-4e9d-9c04-211ae4778d8d" />

<img width="560" height="422" alt="Video analysis results" src="https://github.com/user-attachments/assets/7bd98932-059b-4242-8dcd-346cfc6dc28f" />


