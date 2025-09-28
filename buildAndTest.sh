#!/usr/local/bin/bash
# Test build and run script for ROSS 3D-NoC

set -e  # Exit on error

echo "========================================"
echo "ROSS 3D-NoC Build and Test Script"
echo "========================================"

# Configuration
ROSS_DIR="${ROSS_DIR:-./ROSS}"
BUILD_DIR="${BUILD_DIR:-$ROSS_DIR/build}"
MODEL_NAME="3d-noc"

# Check if ROSS directory exists
if [ ! -d "$ROSS_DIR" ]; then
    echo "Error: ROSS directory not found at $ROSS_DIR"
    echo "Please set ROSS_DIR environment variable or run from correct location"
    exit 1
fi

# Check if model files exist
if [ ! -d "$ROSS_DIR/models/$MODEL_NAME" ]; then
    echo "Error: Model directory not found at $ROSS_DIR/models/$MODEL_NAME"
    exit 1
fi

# Create and enter build directory
echo "Creating build directory..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
echo ""
echo "Configuring with CMake..."

# Try to detect best compiler
if command -v mpicc &> /dev/null; then
    CC_COMPILER="mpicc"
elif command -v gcc-13 &> /dev/null; then
    CC_COMPILER="gcc-13"
elif command -v gcc-12 &> /dev/null; then
    CC_COMPILER="gcc-12"
elif command -v clang &> /dev/null; then
    CC_COMPILER="clang"
else
    CC_COMPILER="cc"
fi

echo "Using compiler: $CC_COMPILER"

cmake .. \
    -DROSS_BUILD_MODELS=ON \
    -DCMAKE_C_COMPILER="$CC_COMPILER" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_VERBOSE_MAKEFILE=ON

# Build the model
echo ""
echo "Building $MODEL_NAME..."
make $MODEL_NAME VERBOSE=1

# Check if build succeeded
if [ -f "models/$MODEL_NAME/$MODEL_NAME" ]; then
    echo ""
    echo "Build successful! Binary created at: $BUILD_DIR/models/$MODEL_NAME/$MODEL_NAME"
    
    # Run basic tests
    echo ""
    echo "Running basic tests..."
    echo "========================================"
    
    # Test 1: Sequential mode, small network
    echo ""
    echo "Test 1: Sequential mode (4x4x4 mesh)"
    ./models/$MODEL_NAME/$MODEL_NAME \
        --synch=1 \
        --noc-x=4 --noc-y=4 --noc-z=4 \
        --noc-topology=0 \
        --workload=0 \
        --end-time=1000 \
        --output=test_mesh_sequential.json
    
    if [ -f "test_mesh_sequential.json" ]; then
        echo "✓ Test 1 passed - output file created"
    else
        echo "✗ Test 1 failed - no output file"
    fi
    
    # Test 2: Conservative mode with MPI (if available)
    if command -v mpirun &> /dev/null; then
        echo ""
        echo "Test 2: Conservative parallel mode (4x4x4 torus)"
        mpirun -np 2 ./models/$MODEL_NAME/$MODEL_NAME \
            --synch=2 \
            --noc-x=4 --noc-y=4 --noc-z=4 \
            --noc-topology=1 \
            --workload=1 \
            --end-time=1000 \
            --output=test_torus_parallel.json
        
        if [ -f "test_torus_parallel.json" ]; then
            echo "✓ Test 2 passed - output file created"
        else
            echo "✗ Test 2 failed - no output file"
        fi
    else
        echo ""
        echo "Skipping Test 2 (MPI not available)"
    fi
    
    # Test 3: Different workload
    echo ""
    echo "Test 3: IoT workload test (4x4x4 hypercube)"
    ./models/$MODEL_NAME/$MODEL_NAME \
        --synch=1 \
        --noc-x=4 --noc-y=4 --noc-z=4 \
        --noc-topology=2 \
        --workload=2 \
        --end-time=1000 \
        --output=test_hypercube_iot.json
    
    if [ -f "test_hypercube_iot.json" ]; then
        echo "✓ Test 3 passed - output file created"
        
        # Display sample results
        echo ""
        echo "Sample results from test_hypercube_iot.json:"
        if command -v python3 &> /dev/null; then
            python3 -c "
import json
with open('test_hypercube_iot.json', 'r') as f:
    data = json.load(f)
    print(f'  Avg Latency: {data[\"performance\"][\"avg_latency_ns\"]} ns')
    print(f'  Avg Throughput: {data[\"performance\"][\"avg_throughput_gbps\"]} Gbps')
    print(f'  Total Power: {data[\"power\"][\"total_power_mw\"]} mW')
"
        else
            head -20 test_hypercube_iot.json
        fi
    else
        echo "✗ Test 3 failed - no output file"
    fi
    
    echo ""
    echo "========================================"
    echo "All tests completed!"
    echo ""
    echo "You can now run more experiments with:"
    echo "  cd $BUILD_DIR"
    echo "  ./models/$MODEL_NAME/$MODEL_NAME --help"
    
else
    echo ""
    echo "Build failed! Check error messages above."
    exit 1
fi
