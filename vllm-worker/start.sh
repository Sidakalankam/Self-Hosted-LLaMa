#!/bin/bash
set -e

echo "=== vLLM Worker Starting ==="

# Required environment variables
: "${MODEL_NAME:?MODEL_NAME is required}"
: "${MODEL_BUCKET:?MODEL_BUCKET is required}"

MODEL_PREFIX="${MODEL_PREFIX:-models/$MODEL_NAME}"
MODEL_DIR="/models/$MODEL_NAME"

MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
PORT="${PORT:-8000}"
PORT_HEALTH="${PORT_HEALTH:-8001}"

echo "Model: $MODEL_NAME"
echo "S3: s3://$MODEL_BUCKET/$MODEL_PREFIX"
echo "Local path: $MODEL_DIR"
echo "vLLM port: $PORT"
echo "Health port: $PORT_HEALTH"

#
# Start health server immediately.
#
# /ping returns:
#   204 while vLLM is unavailable/initializing
#   200 once vLLM is healthy
#
echo "Starting health server on port $PORT_HEALTH..."

python /app/health_server.py &
HEALTH_PID="$!"

# Clean up health server if startup fails.
trap 'kill "$HEALTH_PID" 2>/dev/null || true' EXIT

mkdir -p "$MODEL_DIR"

echo "Downloading model from S3..."

aws s3 sync \
    "s3://$MODEL_BUCKET/$MODEL_PREFIX/" \
    "$MODEL_DIR/"

echo "Model download complete."

echo "Starting vLLM..."

exec vllm serve "$MODEL_DIR" \
    --served-model-name "$MODEL_NAME" \
    --dtype auto \
    --max-model-len "$MAX_MODEL_LEN" \
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
    --host 0.0.0.0 \
    --port "$PORT"
