
#!/bin/bash

# 1. Define Paths
GDS_FILE="mos_cap_test_trying_via.calibre.db"
SCH_NETLIST="mos_cap_test_trying_via.src.net"
TOP_CELL="mos_cap_test_trying_via"
FOUNDRY_LVS="/home/users/madhava/work_tsmc_gp_65_2f/Calibre/lvs/calibre.lvs"
FOUNDRY_SOURCE_ADDED="/home/users/madhava/work_tsmc_gp_65_2f/Calibre/lvs/source.added"

# 2. Setup Aliases
# Using the Top Cell name for the files to satisfy the deck's new search pattern
ln -sf "$GDS_FILE" "$TOP_CELL.gds"
ln -sf "$GDS_FILE" lvs_top.gds

# 3. Create the Wrapper Netlist
echo ".INCLUDE \"$SCH_NETLIST\"" > lvs_wrapper.sp
echo ".INCLUDE \"$FOUNDRY_SOURCE_ADDED\"" >> lvs_wrapper.sp
# Link to the name the deck is specifically asking for now
ln -sf lvs_wrapper.sp "$TOP_CELL.cdl"

# 4. Patch the Top Cell into the foundry rules
# We replace the placeholder and any hardcoded 'lvs_top' defaults
sed -e "s/TOPCELLNAME/$TOP_CELL/g" -e "s/lvs_top/$TOP_CELL/g" "$FOUNDRY_LVS" > local_calibre.lvs

# 5. Create the Barebones SVRF
echo "INCLUDE \"local_calibre.lvs\"" > run_lvs.svrf

# 6. Run Calibre
calibre -lvs -hier run_lvs.svrf
