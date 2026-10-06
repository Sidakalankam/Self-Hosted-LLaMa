#!/bin/bash

set -euo pipefail

echo "========================================"
echo "=== vLLM Worker Starting ==============="
echo "========================================"

#
# Required configuration
#

: "${MODEL_NAME:?MODEL_NAME is required}"

#
# Model source configuration
#

MODEL_SOURCE="${MODEL_SOURCE:-local}"
MODEL_ROOT="${MODEL_ROOT:-/models}"
MODEL_DIR="$MODEL_ROOT/$MODEL_NAME"

#
# vLLM configuration
#

MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
DTYPE="${DTYPE:-auto}"
QUANTIZATION="${QUANTIZATION:-}"

#
# Server configuration
#

PORT="${PORT:-8000}"

echo ""
echo "Configuration:"
echo "  Model:          $MODEL_NAME"
echo "  Model source:   $MODEL_SOURCE"
echo "  Model root:     $MODEL_ROOT"
echo "  Model path:     $MODEL_DIR"
echo "  Port:           $PORT"
echo "  Max context:    $MAX_MODEL_LEN"
echo "  GPU memory:     $GPU_MEMORY_UTILIZATION"
echo "  Dtype:          $DTYPE"

if [ -n "$QUANTIZATION" ]; then
    echo "  Quantization:   $QUANTIZATION"
else
    echo "  Quantization:   auto-detect"
fi

echo ""

#
# Verify persistent model storage exists.
#

if [ ! -d "$MODEL_ROOT" ]; then
    echo "ERROR: Model storage root '$MODEL_ROOT' does not exist."
    exit 1
fi

#
# Handle model source.
#

case "$MODEL_SOURCE" in

    local)
        echo "Using local model."

        if [ ! -d "$MODEL_DIR" ]; then
            echo "ERROR: Local model directory does not exist:"
            echo "  $MODEL_DIR"
            exit 1
        fi
        ;;

    s3)
        : "${MODEL_BUCKET:?MODEL_BUCKET is required when MODEL_SOURCE=s3}"

        MODEL_PREFIX="${MODEL_PREFIX:-models/$MODEL_NAME}"

        echo "Synchronizing model from:"
        echo "  s3://$MODEL_BUCKET/$MODEL_PREFIX"
        echo ""

        mkdir -p "$MODEL_DIR"

        aws s3 sync \
            "s3://$MODEL_BUCKET/$MODEL_PREFIX/" \
            "$MODEL_DIR/" \
            --only-show-errors

        echo ""
        echo "S3 synchronization complete."
        ;;

    *)
        echo "ERROR: Unsupported MODEL_SOURCE: $MODEL_SOURCE"
        echo "Supported values:"
        echo "  local"
        echo "  s3"
        exit 1
        ;;

esac

#
# Basic model sanity checks.
#

if [ ! -f "$MODEL_DIR/config.json" ]; then
    echo "ERROR: config.json does not exist:"
    echo "  $MODEL_DIR/config.json"
    exit 1
fi

if [ ! -f "$MODEL_DIR/tokenizer_config.json" ]; then
    echo "WARNING: tokenizer_config.json was not found."
fi

#
# Verify sharded safetensors.
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

with index_path.open("r", encoding="utf-8") as f:
    index = json.load(f)

weight_map = index.get("weight_map")

if not isinstance(weight_map, dict):
    print(
        f"ERROR: {index_path.name} does not contain "
        "a valid weight_map."
    )
    sys.exit(1)

expected_files = sorted(set(weight_map.values()))

missing_files = [
    filename
    for filename in expected_files
    if not (model_dir / filename).is_file()
]

if missing_files:
    print("ERROR: Missing safetensors shards:")

    for filename in missing_files:
        print(f"  {filename}")

    sys.exit(1)

print(
    f"Validated {len(expected_files)} "
    "safetensors shard file(s)."
)
PY
fi

#
# Display model weights.
#

echo ""
echo "Model weight files:"

find "$MODEL_DIR" \
    -maxdepth 1 \
    -type f \
    \( -name "*.safetensors" -o -name "*.bin" \) \
    -printf "  %f\n" \
    2>/dev/null || true

#
# Construct vLLM command.
#

VLLM_ARGS=(
    "$MODEL_DIR"
    --served-model-name "$MODEL_NAME"
    --dtype "$DTYPE"
    --max-model-len "$MAX_MODEL_LEN"
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION"
    --host 0.0.0.0
    --port "$PORT"
)

#
# Optional explicit quantization override.
#

if [ -n "$QUANTIZATION" ]; then
    VLLM_ARGS+=(
        --quantization "$QUANTIZATION"
    )
fi

echo ""
echo "Starting vLLM..."
echo ""

exec vllm serve "${VLLM_ARGS[@]}"