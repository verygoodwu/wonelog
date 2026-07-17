FROM python:3.13-slim
WORKDIR /app
COPY apps/server/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY apps/server/ ./
COPY data/ ./
RUN mkdir -p /app/posts /app/images /app/versions
EXPOSE 5000
CMD ["python", "-c", "import web_app; web_app.app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)"]