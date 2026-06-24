#!/bin/sh
# Gremlin cleanup for dotnet SBOM upload on Linux (bash/shell runners).

# Modified under MIT license from https://github.com/llamasoft/polyshell
if [ ! -z "${RUNSAFE_DISABLED}" ]; then
    echo "[RunSafe Security] RunSafe protections disabled for this job";
elif [ -z "${RUNSAFE_IDENTIFY_ENABLED}" ]; then
    echo "[RunSafe Security] RunSafe .NET cleanup skipped for this job. Are you sure that Identify is enabled for this project?";
    echo "[RunSafe Security] If that does not resolve the issue, please contact support@runsafesecurity.com."
else
    echo "[RunSafe Security] Generating SBOMs for .NET projects..."
    export RUNSAFE_ROOT_PATH=${GITHUB_WORKSPACE};
    CAPTURE_FILE="${RUNSAFE_DOTNET_PROJECTS_CAPTURE_FILE:-${GITHUB_WORKSPACE}/.dotnet_projects_captured/${GITHUB_RUN_ID}_scan_roots.txt}"

    if [ -f "$CAPTURE_FILE" ] && [ -s "$CAPTURE_FILE" ]; then
      echo "[RunSafe Security] Processing captured .NET project paths for SBOM generation..."

      sort -u "$CAPTURE_FILE" -o "$CAPTURE_FILE"
      if [ -z "${RUNSAFE_ORG_ID}" ]; then
          echo "[RunSafe Security] Warning: RUNSAFE_ORG_ID is not set, skipping .NET SBOM upload (setup may have failed or runsafe.env not loaded)."
      else
          export PATH=${GITHUB_WORKSPACE}/RUNSAFE_SBOM_PACKAGES/bin:${PATH};
          if ! command -v syft >/dev/null 2>&1; then
            echo "[RunSafe Security] Warning: Skipping .NET SBOM generation and upload"
          else
            if ! command -v curl >/dev/null 2>&1; then
                (apt-get update && apt-get install -y curl) 2>/dev/null || (yum install -y curl) 2>/dev/null || (apk add --allow-untrusted curl) 2>/dev/null
            fi
            mkdir -p "${GITHUB_WORKSPACE}/.dotnet_projects_captured" 2>/dev/null || true

            if [ -z "${RUNSAFE_DOTNET_AUDIT_ID}" ]; then
                echo "[RunSafe Security] Error: Could not obtain RUNSAFE_DOTNET_AUDIT_ID from start-audit (curl may have failed). Please review the RunSafe Platform Setup step for any errors. Contact support@runsafesecurity.com if you need assistance."
            else
                while IFS= read -r scan_root || [ -n "$scan_root" ]; do
                  scan_root=$(echo "$scan_root" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                  if [ -z "$scan_root" ]; then
                      continue
                  fi
                  case "$scan_root" in
                      \#*)
                        continue
                        ;;
                  esac

                  case "$scan_root" in
                      /*)
                        runsafe_scan_path="$scan_root"
                        runsafe_scan_file_path="${scan_root#${GITHUB_WORKSPACE}/}"
                        ;;
                      *)
                        runsafe_scan_path="${GITHUB_WORKSPACE}/${scan_root}"
                        runsafe_scan_file_path="$scan_root"
                        ;;
                  esac
                  if [ "$runsafe_scan_file_path" = "${GITHUB_WORKSPACE}" ]; then
                      runsafe_scan_file_path="."
                  fi

                  if [ -f "$runsafe_scan_path" ]; then
                      runsafe_syft_target=$(dirname "$runsafe_scan_path")
                  else
                      runsafe_syft_target="$runsafe_scan_path"
                  fi

                  if [ ! -e "$runsafe_syft_target" ]; then
                      echo "[RunSafe Security] Warning: Skipping missing .NET scan root: $scan_root"
                      continue
                  fi

                  echo "[RunSafe Security] Generating SBOM for .NET scan root: $runsafe_scan_file_path"
                  runsafe_safe_project_name=$(echo "$runsafe_scan_file_path" | sed 's#[^A-Za-z0-9._-]#-#g')
                  runsafe_sbom_file="${GITHUB_WORKSPACE}/.dotnet_projects_captured/sbom-${runsafe_safe_project_name}.cdx.json"

                  if syft "$runsafe_syft_target" --enrich all -o cyclonedx-json > "$runsafe_sbom_file" 2>/dev/null; then
                      echo "[RunSafe Security] Successfully generated SBOM for $runsafe_scan_file_path"
                      RUNSAFE_TEMP_SBOM_ID=$(curl --fail -s -L -X POST \
                        -H "x-runsafe-license-key: ${RUNSAFE_LICENSE_KEY}" \
                        -d "" \
                        "${RUNSAFE_SBOM_SERVER}/api/organizations/${RUNSAFE_ORG_ID}/audits/${RUNSAFE_DOTNET_AUDIT_ID}/start-sbom" || true)

                      if [ -z "${RUNSAFE_TEMP_SBOM_ID}" ]; then
                        echo "[RunSafe Security] Warning: Could not obtain SBOM ID from start-sbom for $runsafe_scan_file_path (empty response; curl may have failed). Skipping upload for this path. Please review the RunSafe Platform Setup step for any errors. Contact support@runsafesecurity.com if you need assistance."
                      else
                        RUNSAFE_HASH=$(sha256sum "${runsafe_sbom_file}" | cut -d' ' -f1)
                        runsafe_project_encoded=$(awk -v s="$runsafe_scan_file_path" 'BEGIN {
                            for (i = 0; i < 256; i++) h[sprintf("%c", i)] = sprintf("%%%02X", i)
                            out = ""
                            for (i = 1; i <= length(s); i++) {
                              c = substr(s, i, 1)
                              if (c ~ /[A-Za-z0-9._~-]/) out = out c
                              else out = out h[c]
                            }
                            printf "%s", out
                        }')
                        runsafe_sbom_upload_exit_code=0
                        curl --fail -sS -L -X PATCH \
                            -H "x-runsafe-license-key: ${RUNSAFE_LICENSE_KEY}" \
                            -H "Content-Type: application/octet-stream" \
                            --data-binary @"${runsafe_sbom_file}" \
                            -o /dev/null \
                            "${RUNSAFE_SBOM_SERVER}/api/organizations/${RUNSAFE_ORG_ID}/audits/${RUNSAFE_DOTNET_AUDIT_ID}/sboms/${RUNSAFE_TEMP_SBOM_ID}?hash=${RUNSAFE_HASH}&status=complete&filePath=${runsafe_project_encoded}" \
                            || runsafe_sbom_upload_exit_code=$?
                        if [ "$runsafe_sbom_upload_exit_code" -eq 0 ]; then
                            echo "[RunSafe Security] Successfully uploaded SBOM for $runsafe_scan_file_path to ${RUNSAFE_SBOM_SERVER}"
                        else
                            echo "[RunSafe Security] Warning: Failed to upload SBOM for $runsafe_scan_file_path (curl exit code: ${runsafe_sbom_upload_exit_code})"
                        fi
                      fi
                      rm -f "${runsafe_sbom_file}" 2>/dev/null || true
                  else
                      echo "[RunSafe Security] Warning: Failed to generate SBOM for $runsafe_scan_file_path"
                  fi
                done < "$CAPTURE_FILE"
                echo "[RunSafe Security] Finished processing .NET projects for SBOM generation"
                FINALIZE_RUNSAFE_DOTNET_AUDIT_URL="${RUNSAFE_SBOM_SERVER}/api/organizations/${RUNSAFE_ORG_ID}/audits/${RUNSAFE_DOTNET_AUDIT_ID}/finalize"
                if ! curl --fail -sS -L -X POST \
                  -H "x-runsafe-license-key: ${RUNSAFE_LICENSE_KEY}" \
                  -H "Accept: application/json" \
                  -H "Content-Type: application/json" \
                  "${FINALIZE_RUNSAFE_DOTNET_AUDIT_URL}" -o /dev/null; then
                  echo "[RunSafe Security] Warning: Failed to finalize .NET audit (finalize API returned an error). Please contact support@runsafesecurity.com."
                fi
            fi
          fi
      fi
    else
      echo "[RunSafe Security] No .NET project capture file found or file is empty (RunSafe .NET interceptor may not have been active or no .NET commands were run)."
      echo "[RunSafe Security] If that is unexpected, please contact support@runsafesecurity.com."
    fi
fi
