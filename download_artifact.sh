#!/bin/bash

# Variables
GITLAB_TOKEN="glpat--J_FSPAGmesKArStLrSc"   # Replace with your GitLab Personal Access Token
PROJECT_ID="66909386"       # Replace with your project ID
CACHE_FILE="artifact_cache.txt"

# Input parameters
JOB_NAME=$1             # First argument: Name of the job
ARTIFACT_NAME=$2        # Second argument: Name of the artifact file
OUTPUT_FILE=$ARTIFACT_NAME  # Save artifact using its name

if [ -z "$JOB_NAME" ] || [ -z "$ARTIFACT_NAME" ]; then
  echo "Usage: $0 <job_name> <artifact_name>"
  exit 1
fi

echo "Fetching artifact '$ARTIFACT_NAME' from job '$JOB_NAME'..."

# Step 1: Get Latest Pipeline
LATEST_PIPELINE=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
"https://gitlab.com/api/v4/projects/$PROJECT_ID/pipelines/latest")

PIPELINE_ID=$(echo $LATEST_PIPELINE | jq -r '.id')
if [ -z "$PIPELINE_ID" ]; then
  echo "Failed to retrieve the latest pipeline. Check project ID and token."
  exit 1
fi

# Step 2: Get Jobs in the Pipeline
JOBS=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
"https://gitlab.com/api/v4/projects/$PROJECT_ID/pipelines/$PIPELINE_ID/jobs")

JOB_ID=$(echo "$JOBS" | jq -r --arg JOB_NAME "$JOB_NAME" '.[] | select(.name == $JOB_NAME and .artifacts_file != null) | .id')

if [ -z "$JOB_ID" ]; then
  echo "No job named '$JOB_NAME' with artifacts found in the latest pipeline."
  exit 1
fi

# Step 3: Get Artifact Metadata
ARTIFACT_DETAILS=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
"https://gitlab.com/api/v4/projects/$PROJECT_ID/jobs/$JOB_ID")
CREATED_AT=$(echo "$ARTIFACT_DETAILS" | jq -r '.created_at')

# Step 4: Check Cache
if [ -f "$CACHE_FILE" ]; then
  CACHED_INFO=$(<"$CACHE_FILE")

  # Compare job name, artifact name, and timestamp stored in the cache
  if echo "$CACHED_INFO" | grep -q "$JOB_NAME|$ARTIFACT_NAME|$CREATED_AT"; then
    echo "Artifact '$ARTIFACT_NAME' from job '$JOB_NAME' is already up-to-date. No download needed."
    exit 0
  fi
fi

# Step 5: Download Artifact
echo "Downloading new artifact '$ARTIFACT_NAME' from job '$JOB_NAME'..."
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
--output "$OUTPUT_FILE" \
"https://gitlab.com/api/v4/projects/$PROJECT_ID/jobs/$JOB_ID/artifacts"

if [ $? -eq 0 ]; then
  echo "Artifact downloaded successfully as '$OUTPUT_FILE'."

  # Update Cache with New Details (job name, artifact name, and timestamp)
  echo "$JOB_NAME|$ARTIFACT_NAME|$CREATED_AT" > $CACHE_FILE
else
  echo "Failed to download artifact."
  exit 1
fi
