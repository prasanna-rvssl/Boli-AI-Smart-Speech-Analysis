# Boli — AI Smart Speech Analysis

Boli extracts useful keywords from live microphone speech and uploaded videos.

## How the demo works

- Live microphone recognition runs in the visitor's browser using its speech recognition service. The microphone permission is requested only after the visitor chooses **Start listening**. Browser support varies; Chrome and Edge are recommended.
- Video uploads are transcribed by the Flask API with faster-whisper using CPU INT8 inference. The API limits uploads to 100 MB.
- The Flutter web app can be published on GitHub Pages. The API can be deployed from `render.yaml` to Render.

## Deploy the API

1. In Render, create a Blueprint from this GitHub repository and select `render.yaml`.
2. Wait for the `boli-api` service to deploy. The first video request downloads the faster-whisper `tiny` model, so it may take longer than later requests.
3. Copy the service URL, for example `https://boli-api.onrender.com`.

The included Blueprint uses Render's free compute plan (512 MB RAM). Free services can spin down after inactivity and take about a minute to wake up. The tiny INT8 model is selected to reduce memory use, but may still exceed the free service limit; if the API returns 502 during transcription, use a service with 2 GB RAM. [Render free-plan limits](https://render.com/docs/free) · [Render compute plans](https://render.com/docs/compute-plans) · [Render pricing](https://render.com/pricing)

## Deploy the web app

1. In the repository's **Settings → Pages**, choose **GitHub Actions** as the publishing source.
2. Under **Settings → Secrets and variables → Actions → Variables**, create the repository variable `API_BASE_URL` with the deployed API URL. Include `https://` and omit the trailing slash.
3. Merge the deployment workflow into `main`, then push a change to `frontend/` or run **Deploy Boli web app** from the Actions tab.
4. The project Pages URL is `https://prasanna-rvssl.github.io/Boli-AI-Smart-Speech-Analysis/`.

If `API_BASE_URL` is not set, live microphone recognition still works, but video upload analysis remains unavailable.
