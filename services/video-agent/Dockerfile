FROM python:3.12-slim

WORKDIR /app

LABEL org.opencontainers.image.title="smartcity-video-agent" \
      org.opencontainers.image.description="Smart City video safety inference agent" \
      org.opencontainers.image.source="https://github.com/Prathamesh18032/MSDSP-432-Final-Project"

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app/services/video-agent

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY services/video-agent/requirements.txt /app/services/video-agent/requirements.txt
RUN pip install --no-cache-dir -r /app/services/video-agent/requirements.txt

COPY services/video-agent /app/services/video-agent
RUN useradd --create-home --uid 10002 smartcity \
    && chown -R smartcity:smartcity /app

USER smartcity

ENTRYPOINT ["python", "-m", "video_agent.main"]

