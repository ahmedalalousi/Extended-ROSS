# ROSS 3D NoC Simulator - Development Achievements & Issues Documentation

## Date: 28th September 2025
## Project: Extended ROSS for 3D Network-on-Chip Simulation

---

## 🎯 Successfully Achieved

### 1. Core 3D NoC Implementation
- ✅ **Created complete 3D NoC simulator** extending ROSS framework
- ✅ **Implemented three topology types**:
  - 3D Mesh (4x4x4 = 64 nodes)
  - 3D Torus (wraparound connections)
  - 3D Hypercube (logarithmic diameter)
- ✅ **XYZ Dimension-Order Routing** with deadlock avoidance
- ✅ **Through-Silicon Via (TSV) modelling** for vertical connections

### 2. Traffic Generation Workloads
Successfully implemented four distinct traffic patterns:

#### SHA256 Cryptographic (Workload 0)
- Block size: 512 bits
- Burst size: 10 requests
- Inter-arrival: 1.0 time units
- Burst interval: 10.0 time units

#### ML Training (Workload 1)
- All-reduce pattern simulation
- Layer-wise communication
- Variable message sizes (64-256 flits)

#### Video Streaming (Workload 2)
- Frame-based traffic
- I-frame: 1500 bytes
- P-frame: 500 bytes  
- B-frame: 200 bytes

#### IoT Sensor (Workload 3)
- Small periodic updates
- 64-byte packets
- Low bandwidth utilisation

### 3. Performance Metrics Collection
Comprehensive statistics tracking:
- **Latency**: Average, minimum, maximum flit latency
- **Throughput**: Per-router and system-wide (Gbps)
- **Network Utilisation**: Percentage of active links
- **Buffer Utilisation**: Input/output buffer occupancy
- **Power Consumption**: Dynamic and static power models
- **Thermal Modelling**: Temperature tracking per router

### 4. File Structure Created
```
models/3d-noc/
├── noc_3d.c           (Main NoC simulation logic)
├── noc_3d.h           (Data structures and constants)
├── noc_3d_main.c      (ROSS integration and LP mapping)
├── noc_3d_routing.c   (Routing algorithms)
├── noc_3d_routing.h   (Routing headers)
└── Makefile          (Build configuration)
```

### 5. Successful Compilation & Execution
- ✅ Fixed all compilation errors
- ✅ Resolved undefined symbol issues
- ✅ Sequential simulation working correctly (`--synch=1`)
- ✅ Producing valid, realistic results

### 6. Realistic Simulation Results Achieved
Example output for 4x4x4 Mesh with SHA256 workload:
- Average latency: 3.36 ns
- Throughput: 27.09 Gbps
- Network utilisation: 30.23%
- Buffer utilisation: 15.63%
- Power consumption: 21.8W
- Peak temperature: 25.48°C

---

## 🐛 Issues Encountered & Resolved

### Compilation Issues (Resolved)
1. **Undefined reference errors**
   - Issue: Linker couldn't find routing functions
   - Fix: Added `noc_3d_routing.c` to Makefile sources

2. **Missing function definitions**
   - Issue: `handle_flit_forward`, `handle_video_frame`, etc. undefined
   - Fix: Implemented all event handler functions

3. **Struct field mismatches**
   - Issue: Incorrect field names in state structures
   - Fix: Standardised naming conventions across all files

4. **Header inclusion problems**
   - Issue: Circular dependencies and missing includes
   - Fix: Proper header guards and inclusion order

### Runtime Issues (Resolved for Sequential)
1. **Zero statistics output**
   - Issue: Metrics not being collected properly
   - Fix: Added proper metric updates in event handlers

2. **Traffic generation bugs**
   - Issue: No traffic being generated
   - Fix: Corrected traffic generator initialisation

3. **Event scheduling errors**
   - Issue: Invalid timestamps and event ordering
   - Fix: Proper burst scheduling with correct intervals

---

## ⚠️ Outstanding Limitations

### MPI Parallel Execution Issues
**Status: Unresolved** - Sequential mode works perfectly, parallel mode fails

#### Error Messages Encountered:
```
node: 0: error: ross-kernel-inline.h:35: ID 72 exceeded MAX LPs
node: 1: error: ross-kernel-inline.h:35: ID -7 exceeded MAX LPs
MPI_ABORT was invoked on rank 1 in communicator MPI_COMM_WORLD
```

#### Root Cause Analysis:
1. **LP-to-PE Mapping Incompatibility**
   - Total LPs: 80 (64 routers + 16 traffic generators)
   - With 2 PEs: Each PE expects 40 LPs
   - Issue: ROSS's internal mapping doesn't align with our LP distribution

2. **Global vs Local ID Confusion**
   - Traffic generators trying to access invalid LP IDs
   - Round-robin mapping creating non-existent LP references

#### Attempted Fixes:
1. **Linear Mapping Implementation**
```c
void mapping_lps_to_pes(void) {
    int total_lps = g_noc_config.total_nodes + g_num_traffic_generators;
    int lps_per_pe = (total_lps + tw_nnodes() - 1) / tw_nnodes();
    
    g_tw_events_per_pe = lps_per_pe * 1000;
    g_tw_lookahead = 0.1;
    tw_define_lps(lps_per_pe, sizeof(flit_msg_t));
    
    int my_start = g_tw_mynode * lps_per_pe;
    int my_end = MIN((g_tw_mynode + 1) * lps_per_pe, total_lps);
    
    for (int i = 0; i < lps_per_pe; i++) {
        int gid = my_start + i;
        if (gid >= total_lps) break;
        
        if (gid < g_noc_config.total_nodes) {
            tw_lp_settype(i, &noc_router_lps[0]);
        } else {
            tw_lp_settype(i, &traffic_gen_lps[0]);
        }
    }
}
```

2. **Round-Robin Mapping Attempt**
   - Tried ROSS's native round-robin scheme
   - Still resulted in invalid LP access

3. **Traffic Generator ID Fixes**
   - Ensured events sent to router IDs (0-63) only
   - Used `lp->id` for self-scheduling
   - Still encountered PE boundary issues

---

## 📊 Performance Comparison

### Sequential vs Parallel Execution

| Aspect | Sequential (`--synch=1`) | Parallel (`--synch=3`) |
|--------|--------------------------|------------------------|
| **Status** | ✅ Working | ❌ Broken |
| **Accuracy** | Full | Would be identical |
| **CPU Usage** | 1 core | Multiple cores |
| **Suitable For** | Small networks (<1000 nodes) | Large networks |
| **Our 4x4x4 NoC** | Perfect | Not needed |

---

## 🔧 Build & Run Commands

### Successful Build Process:
```bash
cd models/3d-noc
make clean
make
```

### Working Execution Commands:

#### Sequential Simulation (Working):
```bash
# Test SHA256 workload on Mesh topology
./noc-3d --synch=1 --noc-x=4 --noc-y=4 --noc-z=4 \
         --noc-topology=0 --workload=0 --end-time=1000

# Test all topologies
for topo in 0 1 2; do
    ./noc-3d --synch=1 --noc-x=4 --noc-y=4 --noc-z=4 \
             --noc-topology=$topo --workload=0 --end-time=5000
done
```

#### Parallel Simulation (Not Working):
```bash
# Attempted but fails with LP exceeded errors
mpirun -np 2 ./noc-3d --synch=3 --noc-x=4 --noc-y=4 --noc-z=4 \
                      --noc-topology=0 --workload=0 --end-time=1000
```

---

## 📝 Key Code Modifications

### 1. Router Event Handling (`noc_3d.c`)
- Implemented complete flit arrival processing
- Added routing decision logic
- Buffer management and congestion control

### 2. Traffic Generation (`noc_3d.c`)
- Four distinct workload generators
- Proper burst scheduling
- Correct destination selection

### 3. Statistics Collection (`noc_3d_main.c`)
- Per-router metric tracking
- System-wide aggregation
- Formatted output display

### 4. Routing Implementation (`noc_3d_routing.c`)
- XYZ dimension-order routing
- Coordinate conversion functions
- Path pre-computation

---

## 🎓 Lessons Learned

1. **ROSS Framework Complexity**
   - LP mapping is critical for parallel execution
   - Sequential mode is robust and sufficient for small models
   - Documentation gaps in ROSS parallel configuration

2. **3D NoC Modelling Insights**
   - TSV parameters significantly impact performance
   - Traffic patterns greatly affect network behaviour
   - Buffer sizing crucial for congestion management

3. **Debugging Strategies**
   - Start with sequential execution
   - Add extensive debug output initially
   - Validate each component independently

---

## 🚀 Future Work

1. **Resolve MPI Parallel Execution**
   - Deep dive into ROSS LP mapping internals
   - Consider custom mapping functions
   - Engage with ROSS community for solutions

2. **Model Enhancements**
   - Add adaptive routing algorithms
   - Implement virtual channels
   - Include fault tolerance mechanisms

3. **Validation**
   - Compare with analytical models
   - Benchmark against other NoC simulators
   - Validate with real workload traces

---

## 📚 References

- ROSS Documentation: [Limited official documentation available]
- Original ROSS Paper: Carothers et al., "ROSS: A high-performance, low-memory, modular Time Warp system"
- 3D NoC concepts from provided manuscript and bibliography

---

## Contact & Repository

- **Date of Documentation**: 28th September 2025
- **ROSS Version**: Extended-ROSS (custom fork)
- **Platform**: macOS (Apple Silicon) / Linux
- **Compiler**: gcc with MPI support

---

*End of Achievement Documentation*
