FROM python:3.9-alpine
WORKDIR /usr/src/app
COPY main.py main.py
ENTRYPOINT ["python", "main.py"]