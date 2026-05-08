# Automated Layout Generation and Verification

## Project Overview

This is a **BTP (Bachelor Thesis Project)** by **Madhava Sriram (22b1233)** supervised by **Prof. Maryam Shojaei Baghini** with mentors **Moin Shaikh** and **Prajwal**.

The project focuses on automating the creation and verification of integrated circuit layouts. Given a circuit schematic (in this case, a rectifier consisting of 2 MOSFETs and a capacitor), the goal is to:

- **Automate layout creation** using SKILL scripting to reduce manual design effort
- **Generate optimized versions** of layouts by parametrically varying component dimensions and placement
- **Verify designs automatically** through DRC, LVS, PEX checks, and post-layout simulation
- **Achieve performance at par with or better than manually designed layouts**

## Problem Statement

Manual IC layout design is time-consuming and iterative. Designers spend considerable time creating layouts, observing design metrics, and iterating to improve performance. This project automates the process to accelerate design cycles and reduce human effort while maintaining or improving design quality.

## Key Technologies & Terminology

### SKILL Scripting Engine
Cadence's internal automation scripting language used to programmatically generate component layouts without manual GUI interaction.

### Verification Stages

- **DRC (Design Rule Check)**: Verifies that the physical layout follows manufacturing/fabrication design rules
- **LVS (Layout Versus Schematic)**: Checks that the extracted layout netlist matches the original schematic electrically
- **PEX (Parasitic Extraction)**: Extracts parasitic resistances, capacitances, and inductances from the layout for accurate post-layout simulation

### Performance Metrics

- **PCE (Power Conversion Efficiency)**: Ratio of useful output power to input power (expressed as percentage) indicating how efficiently energy is converted

## Project Flow

The complete automated flow executes in non-GUI mode:

```
virtuoso -nograph -restore
    ↓
create_layout_parameterised_nothardcoded.il (SKILL code)
    ↓
run_full_flow_with_checks.sh (Orchestration script)
    ↓ 
DRC → LVS → PEX → Post-layout Simulation
    ↓
Output: PCE Results
```

## Layout Generation Features

### Parameterization

The layout generation supports the following tunable parameters:

- `LENGTH_OF_MOSFET`: MOSFET channel length
- `WIDTH_OF_MOSFET`: MOSFET channel width
- `LENGTH_OF_CAP`: Capacitor length
- `WIDTH_OF_CAP`: Capacitor width
- `NUMBER_OF_FINGERS`: Number of parallel fingers in MOSFETs

### Automatic Routing

Implemented `placeRobustRoute()` function that:
- Automatically connects component terminals without hardcoded routing coordinates
- Avoids metal wire intersections and DRC violations
- Intelligently routes to higher metal layers when necessary

## Running the Project

### Main Execution Script

```bash
./run_full_flow_with_checks.sh
```

This master script:
1. Performs DRC (Design Rule Check)
2. Runs LVS (Layout Versus Schematic) verification
3. Executes PEX (Parasitic Extraction)
4. Runs post-layout simulation
5. Extracts and reports PCE values
6. Handles input power sweep to find PCE at target input power (-30dBm)

### Individual Verification Scripts

Run individual verification steps if needed:

```bash
./run_drc.sh      # Design Rule Check
./run_lvs.sh      # Layout Versus Schematic Check
./run_pex.sh      # Parasitic Extraction
./run_sim.ocn     # Post-layout Simulation
```

## Project Files

- **create_layout_parameterised_nothardcoded.il**: SKILL script for parameterized layout generation using Cadence Virtuoso
- **run_full_flow_with_checks.sh**: Main orchestration script that executes the complete verification pipeline
- **run_drc.sh**: Design Rule Check verification
- **run_lvs.sh**: Layout Versus Schematic verification
- **run_pex.sh**: Parasitic Extraction
- **run_sim.ocn**: OCEAN script for post-layout simulation
- **BTP-2 presentation.pdf**: Project presentation with detailed technical background
- **BTP2 Weekly Documentation.pdf**: Weekly progress documentation

## Design Approach

### Phase 1: Initial Hardcoded Layout
Started with fully hardcoded component coordinates to establish a working baseline and verify the complete flow through the Cadence GUI.

### Phase 2: Parametrization
Generalized the layout to support tunable parameters for component dimensions, enabling systematic exploration of design space.

### Phase 3: Automatic Routing Generalization
Removed hardcoded routing by implementing intelligent connection functions that automatically generate wiring while avoiding DRC violations.

## Key Results

- Successfully automated the entire layout-to-verification pipeline
- Achieved ~46% Power Conversion Efficiency (PCE) at -30dBm input power
- Performance is comparable to manually designed layouts created by experienced designers
- Enables rapid design iteration and optimization

## Technology Stack

- **CAD Tool**: Cadence Virtuoso (non-GUI mode)
- **Scripting**: SKILL (Cadence automation language)
- **Process Technology**: TSMC 65nm (N65)
- **Verification**: Calibre DRC/LVS/RCX
- **Simulation**: OCEAN, SPICE

## Notes

- All operations execute in non-GUI mode via Virtuoso command line
- DRC/LVS/PEX checks automatically ignore known non-critical rule violations
- The design includes external parasitic inductances and capacitances for realistic simulation
- Layout modifications can be tested automatically via the main flow script to assess improvements
