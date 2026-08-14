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

echo "Model: $MODEL_NAME"
echo "S3: s3://$MODEL_BUCKET/$MODEL_PREFIX"
echo "Local path: $MODEL_DIR"

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
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION"