
#!/bin/bash
set -e  # Exit immediately if a command fails

echo "--- First extacting the most recent layout file ---"

strmout -library trying_tsmc -topCell mos_cap_test_trying_via -view layout -strmFile mos_cap_test_trying_via.calibre.db -logFile strmout.log -summaryFile strmout.sum -techLib tsmcN65 -runDir .

echo "--- Starting DRC Run ---"

# 1. Define Paths
GDS_FILE="mos_cap_test_trying_via.calibre.db"
TOP_CELL="mos_cap_test_trying_via"
FOUNDRY_DRC="/home/users/madhava/work_tsmc_gp_65_2f/Calibre/drc/calibre.drc"

echo "Using GDS: $GDS_FILE"

# 2. Create symbolic link
echo "Creating GDS link..."
ln -sf "$GDS_FILE" GDSFILENAME

# 3. Patch the rule deck
echo "Patching rule deck into local_calibre.drc..."
sed "s/LAYOUT PRIMARY \"TOPCELLNAME\"/LAYOUT PRIMARY \"$TOP_CELL\"/" "$FOUNDRY_DRC" > local_calibre.drc

# 4. Create SVRF wrapper
echo "Creating run_drc.svrf..."
echo "INCLUDE \"local_calibre.drc\"" > run_drc.svrf

# 5. Execute Calibre
echo "Launching Calibre..."
calibre -drc -hier run_drc.svrf







