#!/bin/bash

BASE_DIR="/storage/brno12-cerit/home/petraskkar"
RUN_DIR="${BASE_DIR}/RESULTS/statistics_results"
SAMPLES_DIR="${RUN_DIR}/statistics_output_${RUN_NUMBER}"
ENV_DIR="${BASE_DIR}/conda_envs/env_stats_alignment"

# 1. Load the conda manager
module load mambaforge
eval "$(conda shell.bash hook)"

# 2. Activate your environment where multiqc is installed
conda activate "$ENV_DIR"

# 3. Verify it is accessible
multiqc --version

# 4. Navigate to your output directory and generate the report
cd "$SAMPLES_DIR"
multiqc . -o multiqc_report