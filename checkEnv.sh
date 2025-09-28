#!/usr/local/bin/bash
# Environment check script for building ROSS 3D-NoC on macOS

echo "========================================"
echo "ROSS 3D-NoC Build Environment Check"
echo "========================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if environment is ready
READY=true

# Function to check command existence
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $2 found: $(command -v $1)"
        if [ ! -z "$3" ]; then
            echo "  Version: $($1 $3 2>&1 | head -n 1)"
        fi
        return 0
    else
        echo -e "${RED}✗${NC} $2 NOT found"
        READY=false
        return 1
    fi
}

# Function to check library
check_library() {
    if pkg-config --exists $1 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $2 found via pkg-config"
        echo "  Version: $(pkg-config --modversion $1)"
        return 0
    elif [ -f /usr/local/lib/lib$1.dylib ] || [ -f /opt/homebrew/lib/lib$1.dylib ]; then
        echo -e "${GREEN}✓${NC} $2 library found"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $2 may not be installed (check manually)"
        return 1
    fi
}

echo "1. Checking Compilers"
echo "---------------------"

# Check for C compilers
echo "Native Apple Clang:"
if xcode-select -p &> /dev/null; then
    echo -e "${GREEN}✓${NC} Xcode Command Line Tools installed"
    check_command "clang" "Apple Clang" "--version"
else
    echo -e "${RED}✗${NC} Xcode Command Line Tools NOT installed"
    echo "  Run: xcode-select --install"
    READY=false
fi

echo ""
echo "GNU Compiler:"
check_command "gcc-13" "GCC 13" "--version" || \
check_command "gcc-12" "GCC 12" "--version" || \
check_command "gcc-11" "GCC 11" "--version" || \
check_command "gcc" "GCC" "--version"

echo ""
echo "2. Checking Build Tools"
echo "-----------------------"
check_command "cmake" "CMake" "--version"
check_command "make" "Make" "--version"

echo ""
echo "3. Checking MPI Implementation"
echo "------------------------------"

# Check for different MPI implementations
MPI_FOUND=false

if check_command "mpicc" "MPI Compiler" "--version"; then
    MPI_FOUND=true
    echo "  MPI Include: $(mpicc -showme:compile 2>/dev/null || echo 'N/A')"
    echo "  MPI Libs: $(mpicc -showme:link 2>/dev/null || echo 'N/A')"
fi

if ! $MPI_FOUND && command -v brew &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} MPI not found. Install with: brew install open-mpi"
    READY=false
fi

echo ""
echo "4. Checking ROSS Installation"
echo "-----------------------------"

# Check if ROSS directory exists
if [ -d "$(pwd)/ROSS" ]; then
    echo -e "${GREEN}✓${NC} ROSS directory found at: $(pwd)/ROSS"
    
    # Check if our model is in place
    if [ -d "$(pwd)/ROSS/models/3d-noc" ]; then
        echo -e "${GREEN}✓${NC} 3D-NoC model directory found"
        
        # Check for required files
        for file in noc_3d.h noc_3d.c noc_3d_main.c CMakeLists.txt; do
            if [ -f "$(pwd)/ROSS/models/3d-noc/$file" ]; then
                echo -e "${GREEN}✓${NC}   $file present"
            else
                echo -e "${RED}✗${NC}   $file MISSING"
                READY=false
            fi
        done
    else
        echo -e "${RED}✗${NC} 3D-NoC model directory not found at ROSS/models/3d-noc"
        READY=false
    fi
else
    echo -e "${RED}✗${NC} ROSS directory not found in current path"
    echo "  Please run this from the parent directory of ROSS"
    READY=false
fi

echo ""
echo "5. Checking for macOS-specific Issues"
echo "-------------------------------------"

# Check macOS version
echo "macOS Version: $(sw_vers -productVersion)"

# Check for Homebrew (common package manager)
if command -v brew &> /dev/null; then
    echo -e "${GREEN}✓${NC} Homebrew installed: $(brew --prefix)"
else
    echo -e "${YELLOW}⚠${NC} Homebrew not found (optional but recommended)"
fi

# Check for common issues with MPI on Mac
if [ -f /etc/hosts ]; then
    if grep -q "127.0.0.1.*localhost" /etc/hosts; then
        echo -e "${GREEN}✓${NC} /etc/hosts has localhost entry"
    else
        echo -e "${YELLOW}⚠${NC} /etc/hosts may need localhost entry for MPI"
    fi
fi

echo ""
echo "6. Build Test Commands"
echo "----------------------"

if $READY; then
    echo -e "${GREEN}Environment appears ready!${NC}"
    echo ""
    echo "To build ROSS with 3D-NoC, run these commands:"
    echo ""
    echo "  cd ROSS"
    echo "  mkdir -p build"
    echo "  cd build"
    echo ""
    echo "For GNU compiler (if installed):"
    echo "  cmake .. -DROSS_BUILD_MODELS=ON \\"
    echo "           -DCMAKE_C_COMPILER=$(which gcc-13 || which gcc-12 || which gcc-11 || which gcc || echo mpicc) \\"
    echo "           -DCMAKE_BUILD_TYPE=Debug"
    echo ""
    echo "For Apple Clang:"
    echo "  cmake .. -DROSS_BUILD_MODELS=ON \\"
    echo "           -DCMAKE_C_COMPILER=$(which clang || echo cc) \\"
    echo "           -DCMAKE_BUILD_TYPE=Debug"
    echo ""
    echo "Then build with:"
    echo "  make 3d-noc"
else
    echo -e "${RED}Environment NOT ready!${NC}"
    echo ""
    echo "Please install missing components:"
    
    if ! command -v mpicc &> /dev/null; then
        echo "  brew install open-mpi"
    fi
    
    if ! command -v cmake &> /dev/null; then
        echo "  brew install cmake"
    fi
    
    if ! xcode-select -p &> /dev/null; then
        echo "  xcode-select --install"
    fi
fi

echo ""
echo "========================================"
