  GNU nano 2.3.1                                                                                                                                                                                         File: run_full_flow_with_checks.sh                                                                                                                                                                                                                                                                                                                                                                                          

#!/bin/bash


# 0. AGGRESSIVE CLEAN SLATE
# Delete everything that OCEAN or Calibre might reuse
rm -f terminal_results.csv
rm -f DRC.rep LVS.rep
rm -f mos_cap_test_trying_via.calibre.db  # Kill the GDS
rm -f mos_cap_test_trying_via.pex.netlist # Kill the netlist
rm -f net.dist* # Kill any PEX variants
rm -f sim.log

echo -n "Step 1: Running DRC... "
./run_drc.sh > /dev/null 2>&1

# 1. DEFINE IGNORED VIOLATIONS (Rule Names Only)
# Any rule in this list will be bypassed regardless of its count.
ignored_rules=(
    "OD.DN.1L" "DOD.R.1" "PO.DN.1L" "DPO.R.1" "M9.DN.1L" "CBM.S.3"
    "CSR.R.1.NWi" "CSR.R.1.PPi" "CSR.R.1.NPi" "CSR.R.1.COi" "CSR.R.1.NT_Ni"
    "CSR.R.1.CBMi" "CSR.R.1.CTMi" "CSR.R.1.CTMDMY" "CSR.R.1.CTMDMY_20"
    "CSR.R.1.RFDMY" "CSR.R.1.M1i" "CSR.R.1.M1_real" "CSR.R.1.M2i"
    "CSR.R.1.M2_real" "CSR.R.1.M3i" "CSR.R.1.M3_real" "CSR.R.1.M4i"
    "CSR.R.1.M4_real" "CSR.R.1.M5i" "CSR.R.1.M5_real" "CSR.R.1.M6i"
    "CSR.R.1.M6_real" "CSR.R.1.M7i" "CSR.R.1.M7_real" "CSR.R.1.M8_NEW"
    "CSR.R.1.VIA1i" "CSR.R.1.VIA2i" "CSR.R.1.VIA3i" "CSR.R.1.VIA4i"
    "CSR.R.1.VIA5i" "CSR.R.1.VIA6i" "CSR.R.1.VIA7_NEW" "CSR.R.1.ODi"
    "CSR.R.1.POi" "DM1.R.1" "DM2.R.1" "DM3.R.1" "DM4.R.1" "DM5.R.1"
    "DM6.R.1" "DM7.R.1" "DM8.R.1" "DM9.R.1" "ESD.WARN.1" "PO.R.8"
)

# 2. CHECK CURRENT DRC.REP
FAIL_FLAG=0

# Ensure DRC.rep exists before parsing
if [ ! -f DRC.rep ]; then
    echo -e "\nERROR: DRC.rep was not generated. Exiting."
    exit 1
fi

# Extract rules that have a count > 0 from the report
CURRENT_RULES=$(grep "Result Count =" DRC.rep | sed 's/[()]//g' | awk '$NF > 0 {print $2}')

for RULE in $CURRENT_RULES; do
    MATCH=0
    # Check if the current rule exists in our ignored list
    for IGNORED in "${ignored_rules[@]}"; do
        if [[ "$RULE" == "$IGNORED" ]]; then
            MATCH=1
            break
        fi
    done

    # If the rule is NOT in the ignore list, it's a critical error
    if [ $MATCH -eq 0 ]; then
        echo -e "\n!!! CRITICAL DRC ERROR FOUND: $RULE"
        echo "This rule is not in the ignore list. Terminating flow."
        FAIL_FLAG=1
    fi
done

if [ $FAIL_FLAG -eq 1 ]; then
    echo "------------------------------------------------"
    echo "DRC Validation Failed. Exiting."
    echo "------------------------------------------------"
    exit 1
else
    echo "Done (Verified known violations)."
fi

# 3. LVS CHECK
echo -n "Step 2a: Running LVS... "
./run_lvs.sh > /dev/null 2>&1
if grep -qiE "CONGRATULATIONS|CORRECT" lvs.rep; then
    echo "Done (LVS Clean)."
else
    echo -e "\n!!! LVS FAILED. Circuit mismatch or short found. Exiting."
    exit 1
fi

# 4. PEX CHECK
echo -n "Step 2b: Running PEX... "
./run_pex.sh > /dev/null 2>&1

if [ -s "net.dist" ]; then
    # This is the 'Handshake' - renaming the file so OCEAN can find it
    mv net.dist mos_cap_test_trying_via.pex.netlist
    echo "Done (Netlist synced)."
else
    echo -e "\n!!! PEX FAILED. 'net.dist' was not found. Exiting."
    exit 1
fi

# 5. SIMULATION
echo -n "Step 3: Running Simulation... "
ocean -restore run_sim.ocn > sim.log 2>&1

if [ -f terminal_results.csv ]; then
    echo "Done."
else
    echo -e "\n!!! Simulation Failed. Check sim.log for errors. Exiting."
    exit 1
fi

echo "------------------------------------------------"
# Calculate results from the fresh CSV
awk -F, 'BEGIN {min=100; val=0} {diff=$2+30; if(diff<0) diff=-diff; if(diff<min) {min=diff; val=$3; pin=$2}} END {printf "Target Pin: -30.00 dBm | Actual Pin: %.2f dBm\nFINAL PCE:  %.2f%%\n", pin, val}' terminal_results.csv
echo "------------------------------------------------"




