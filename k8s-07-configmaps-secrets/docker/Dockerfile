# Project 07 - ConfigMaps & Secrets Dockerfile
# Same Dockerfile as previous projects, but we'll configure it via ConfigMaps/Secrets

FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY app/requirements.txt .

# Add trusted hosts for corporate networks (if needed)
RUN pip install --no-cache-dir \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org \
    -r requirements.txt

# Copy application code
COPY app/main.py .

# Create directories for config and secrets (will be mounted by Kubernetes)
RUN mkdir -p /etc/config /etc/secrets

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
