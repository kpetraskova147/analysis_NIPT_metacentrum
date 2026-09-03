# Path to your NanoStat output
NANOSTAT_FILE="nanostat_${RUN_NUMBER}_${BARCODE}.txt"

# 1. Extract the three critical metrics using awk
# We remove commas and decimals to allow Bash integer comparison
RAW_READS=$(grep "Number of reads:" "$NANOSTAT_FILE" | awk '{print $4}' | sed 's/,//g' | cut -d'.' -f1)
MED_LEN=$(grep "Median read length:" "$NANOSTAT_FILE" | awk '{print $4}' | cut -d'.' -f1)
MED_QUAL=$(grep "Median read quality:" "$NANOSTAT_FILE" | awk '{print $4}' | cut -d'.' -f1)
AVG_IDENTITY=$(grep "Average percent identity:" "$NANOSTAT_FILE" | awk '{print $4}') 

# 2. Evaluate against thresholds
POOR_ACCURACY=$(awk -v id="$AVG_IDENTITY" 'BEGIN { if(id < 96.8) print 1; else print 0 }') 

SEQ_QC_STATUS="PASS"

if [ "$RAW_READS" -lt 3000000 ]; then
    SEQ_QC_STATUS="FAIL (Low Reads)"
elif [ "$MED_LEN" -lt 140 ] || [ "$MED_LEN" -gt 250 ]; then
    SEQ_QC_STATUS="FAIL (Contamination)"
elif [ "$MED_QUAL" -lt 15 ]; then
    SEQ_QC_STATUS="FAIL (Poor Quality)"
elif [ "$POOR_ACCURACY" -eq 1 ]; then
    SEQ_QC_STATUS="FAIL (Poor Accuracy)"
fi

echo ">> Sequencing QC Status: $SEQ_QC_STATUS" | tee -a "$JOB_LOG"
echo ">> Basecalling Accuracy: $AVG_IDENTITY %" | tee -a "$JOB_LOG"

# 3. Export to environment for Python/R to pick up
export SEQ_QC_STATUS
export AVG_IDENTITY 