FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY apps/streamlit/requirements.txt /app/apps/streamlit/requirements.txt
RUN pip install --no-cache-dir -r /app/apps/streamlit/requirements.txt

COPY apps/streamlit /app/apps/streamlit

EXPOSE 8501

CMD ["streamlit", "run", "apps/streamlit/app.py", "--server.address=0.0.0.0", "--server.port=8501", "--server.headless=true", "--browser.gatherUsageStats=false"]
