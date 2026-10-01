#!/bin/bash

set -euo pipefail

echo "========================================"
echo "=== vLLM Worker Starting ==============="
echo "========================================"

#
# Required environment variables
#

: "${MODEL_NAME:?MODEL_NAME is required}"
: "${MODEL_BUCKET:?MODEL_BUCKET is required}"

#
# Optional configuration
#

MODEL_PREFIX="${MODEL_PREFIX:-models/$MODEL_NAME}"

MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"

PORT="${PORT:-8000}"

# Persistent storage location inside the container.
# Infrastructure should mount persistent storage here.
#
# Examples:
#   EC2 + EBS:              /models
#   RunPod network volume:  /runpod-volume/models
#
MODEL_ROOT="${MODEL_ROOT:-/models}"
MODEL_DIR="$MODEL_ROOT/$MODEL_NAME"

echo ""
echo "Configuration:"
echo "  Model:        $MODEL_NAME"
echo "  S3 source:    s3://$MODEL_BUCKET/$MODEL_PREFIX"
echo "  Model root:   $MODEL_ROOT"
echo "  Model path:   $MODEL_DIR"
echo "  Port:         $PORT"
echo "  Max context:  $MAX_MODEL_LEN"
echo "  GPU memory:   $GPU_MEMORY_UTILIZATION"
echo ""

#
# Verify the persistent storage location exists.
#

if [ ! -d "$MODEL_ROOT" ]; then
    echo "ERROR: Model storage root '$MODEL_ROOT' does not exist."
    echo "Make sure persistent storage is mounted into the container."
    exit 1
fi

mkdir -p "$MODEL_DIR"

#
# Synchronize model from S3.
#
# This runs on every worker startup.
#
# If the model is already cached on persistent storage, AWS CLI will
# compare the files and avoid downloading unchanged files again.
#
# If a previous worker stopped during the download, sync will download
# missing or changed files.
#

echo "Synchronizing model from S3..."
echo ""

aws s3 sync \
    "s3://$MODEL_BUCKET/$MODEL_PREFIX/" \
    "$MODEL_DIR/" \
    --only-show-errors

echo ""
echo "S3 synchronization complete."

#
# Basic sanity checks.
#

if [ ! -f "$MODEL_DIR/config.json" ]; then
    echo "ERROR: config.json does not exist after S3 sync."
    exit 1
fi

if [ ! -f "$MODEL_DIR/tokenizer_config.json" ]; then
    echo "WARNING: tokenizer_config.json was not found."
fi

#
# Verify sharded safetensors files before vLLM starts.
#

SAFETENSORS_INDEX="$MODEL_DIR/model.safetensors.index.json"

if [ -f "$SAFETENSORS_INDEX" ]; then
    echo "Validating safetensors shards..."

    python3 - "$SAFETENSORS_INDEX" "$MODEL_DIR" <<'PY'
import json
import sys
from pathlib import Path

index_path = Path(sys.argv[1])
model_dir = Path(sys.argv[2])

with index_path.open("r", encoding="utf-8") as index_file:
    index = json.load(index_file)

weight_map = index.get("weight_map")

if not isinstance(weight_map, dict):
    print(f"ERROR: {index_path.name} does not contain a valid weight_map.")
    sys.exit(1)

expected_files = sorted(set(weight_map.values()))

missing_files = [
    filename
    for filename in expected_files
    if not (model_dir / filename).is_file()
]

if missing_files:
    print("ERROR: model.safetensors.index.json references missing shard files:")

    for filename in missing_files:
        print(f"  {filename}")

    sys.exit(1)

print(f"Validated {len(expected_files)} safetensors shard file(s).")
PY
fi

#
# Print the model weight files that are available.
#

echo ""
echo "Model weight files:"

find "$MODEL_DIR" \
    -maxdepth 1 \
    -type f \
    \( -name "*.safetensors" -o -name "*.bin" \) \
    -printf "  %f\n" \
    2>/dev/null || true

echo ""
echo "Starting vLLM..."
echo ""

#
# Replace this shell process with vLLM.
#
# This makes vLLM PID 1 so that it receives container shutdown
# signals directly.
#

exec vllm serve "$MODEL_DIR" \
    --served-model-name "$MODEL_NAME" \
    --dtype auto \
    --max-model-len "$MAX_MODEL_LEN" \
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
    --host 0.0.0.0 \
    --port "$PORT"