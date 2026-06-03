FROM python:3.12-slim

WORKDIR /app

LABEL org.opencontainers.image.title="smartcity-streamlit" \
      org.opencontainers.image.description="Smart City operations command center and reporting app" \
      org.opencontainers.image.source="https://github.com/Prathamesh18032/MSDSP-432-Final-Project"

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV STREAMLIT_THEME_BASE=light
ENV STREAMLIT_THEME_BACKGROUND_COLOR=#f7f8fb
ENV STREAMLIT_THEME_SECONDARY_BACKGROUND_COLOR=#ffffff
ENV STREAMLIT_THEME_TEXT_COLOR=#101828
ENV STREAMLIT_THEME_PRIMARY_COLOR=#0f766e

COPY apps/streamlit/requirements.txt /app/apps/streamlit/requirements.txt
RUN pip install --no-cache-dir -r /app/apps/streamlit/requirements.txt

COPY apps/streamlit /app/apps/streamlit
RUN useradd --create-home --uid 10001 smartcity \
    && chown -R smartcity:smartcity /app

USER smartcity

EXPOSE 8501

CMD ["streamlit", "run", "apps/streamlit/app.py", "--server.address=0.0.0.0", "--server.port=8501", "--server.headless=true", "--browser.gatherUsageStats=false"]
