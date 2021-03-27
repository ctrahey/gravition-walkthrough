FROM python:3.9-alpine
WORKDIR /usr/src/app
COPY main.py main.py
RUN pip install --upgrade pip

COPY requirements.txt ./
RUN /usr/local/bin/python -m pip install --no-cache-dir -r requirements.txt
ENTRYPOINT ["python", "main.py"]