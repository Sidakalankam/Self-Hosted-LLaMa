#!/bin/bash
set -e

echo "=== vLLM Worker Starting ==="

: "${MODEL_NAME:?MODEL_NAME is required}"
: "${MODEL_BUCKET:?MODEL_BUCKET is required}"

MODEL_PREFIX="${MODEL_PREFIX:-models/$MODEL_NAME}"

# Persistent Runpod network volume
MODEL_DIR="/runpod-volume/models/$MODEL_NAME"

MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
PORT="${PORT:-8000}"
PORT_HEALTH="${PORT_HEALTH:-8001}"

echo "Model: $MODEL_NAME"
echo "S3 source: s3://$MODEL_BUCKET/$MODEL_PREFIX"
echo "Persistent model path: $MODEL_DIR"
echo "vLLM port: $PORT"
echo "Health port: $PORT_HEALTH"

# Start health server immediately.
python /app/health_server.py &
HEALTH_PID="$!"

trap 'kill "$HEALTH_PID" 2>/dev/null || true' EXIT

mkdir -p "$MODEL_DIR"

# Only download if model isn't already cached.
if [ ! -f "$MODEL_DIR/config.json" ]; then
    echo "Model not found on network volume."
    echo "Downloading model from S3..."

    aws s3 sync \
        "s3://$MODEL_BUCKET/$MODEL_PREFIX/" \
        "$MODEL_DIR/"

    echo "Model download complete."
    echo "Model is now cached at $MODEL_DIR."
else
    echo "Model already exists on network volume."
    echo "Skipping S3 download."
fi

echo "Starting vLLM..."

exec vllm serve "$MODEL_DIR" \
    --served-model-name "$MODEL_NAME" \
    --dtype auto \
    --max-model-len "$MAX_MODEL_LEN" \
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
    --host 0.0.0.0 \
    --port "$PORT"
