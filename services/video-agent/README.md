# Smart City Video Agent

The video agent is an optional MVP inference worker. It does not use an LLM, external model API, training job, or fine-tuning path. In real image mode it runs a local two-stage Hugging Face classifier: Crime/Normal first, then a UCF-Crime activity-type hint for frames that clear the suspicious threshold. In mock mode it emits deterministic predictions for local smoke tests.

## Local Mock Path

```sh
make run-local
mkdir -p data/video_inbox/city=chicago/camera=demo-001
touch data/video_inbox/city=chicago/camera=demo-001/robbery-sample.mp4
VIDEO_AGENT_MOCK_MODEL=true make run-video-agent-once
```

Mock mode is the default so `make ai-check` and CI do not download PyTorch models.

## Real Inference Path

```sh
python3 -m pip install -r services/video-agent/requirements.txt
VIDEO_AGENT_MOCK_MODEL=false make run-video-agent-once
```

Default real-image models:

```text
VIDEO_AGENT_BINARY_MODEL=dima806/crime_cctv_image_detection
VIDEO_AGENT_TYPE_MODEL=dima806/crime_type_cctv_image_detection
VIDEO_AGENT_CRIME_THRESHOLD=0.50
```

The model output is treated as "AI-flagged possible activity for human review", not a confirmed crime.

## Dataset And Frame Demo

```sh
make seed-video-dataset
VIDEO_AGENT_SOURCE_VIDEO=/path/to/demo.mp4 make extract-video-frames
```

`make seed-video-dataset` uses Kaggle credentials when `VIDEO_AGENT_DATASET_SOURCE_DIR` is not set, samples selected UCF-Crime `Test` image folders, and keeps the output under `VIDEO_AGENT_DATASET_MAX_MB` in `data/video_inbox`.

## GCS Input Shape

```text
gs://<GCS_BUCKET>/video_inbox/city=chicago/camera=demo-assault/example.jpg
```

Cloud deployment can process Cloud Storage `OBJECT_FINALIZE` notifications from a Pub/Sub subscription.
