#!/bin/bash

# 1. CLEANUP
rm -rf svdb
rm -f local_calibre2.rcx

# 2. Define Paths
TOP_CELL="mos_cap_test_trying_via"
GDS_FILE="mos_cap_test_trying_via.gds"
SCH_NETLIST="mos_cap_test_trying_via.src.net"
FOUNDRY_PEX="/home/users/madhava/work_tsmc_gp_65_2f/Calibre/rcx/calibre2.rcx"

# 3. Create the SVRF Wrapper
cat << 'EOT' > run_pex.svrf
LAYOUT PATH  "mos_cap_test_trying_via.gds"
LAYOUT PRIMARY "mos_cap_test_trying_via"
LAYOUT SYSTEM GDS

SOURCE PATH  "mos_cap_test_trying_via.src.net"
SOURCE PRIMARY "mos_cap_test_trying_via"
SOURCE SYSTEM SPICE

MASK SVDB DIRECTORY "svdb" XRC PHDB
VARIABLE RC_EXTRACT_MODE "RCC"

INCLUDE "local_calibre2.rcx"
EOT

# 4. Patch the foundry deck
# We use 'd' in sed to DELETE conflicting lines entirely from the local copy
sed -e "s/TOPCELLNAME/$TOP_CELL/g" \
    -e "s/lvs_top/$TOP_CELL/g" \
    -e '/LAYOUT SYSTEM/d' \
    -e '/SOURCE SYSTEM/d' \
    -e '/LAYOUT PRIMARY/d' \
    -e '/SOURCE PRIMARY/d' \
    -e '/LAYOUT PATH/d' \
    -e '/SOURCE PATH/d' \
    -e '/MASK SVDB DIRECTORY/d' \
    "$FOUNDRY_PEX" > local_calibre2.rcx

# 5. Execute PEX
echo "--- Stage 1: Extraction (PHDB) ---"
calibre -xrc -phdb run_pex.svrf

echo "--- Stage 2: Parasitic Analysis (PDB) ---"
calibre -xrc -pdb  run_pex.svrf

echo "--- Stage 3: Formatting Netlist (FMT) ---"
calibre -xrc -fmt  run_pex.svrf

