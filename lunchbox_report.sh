#!/bin/bash
# Written By Kyle Butler
# Tested on 6.29.2021 on prisma_cloud_enterprise_edition using Ubuntu 20.04

# Requires jq to be installed sudo apt-get install jq

# Access key should be created in the Prisma Cloud Console under: Settings > Accesskeys
# Decision to leave access keys in the script to simplify the workflow
# Recommendations for hardening are: store variables in a secret manager of choice or export the access_keys/secret_key as env variables in a separate script. 

# Place the access key and secret key between "<ACCESS_KEY>", <SECRET_KEY> marks respectively below.


# Only variable(s) needing to be assigned by and end-user
# Found on https://prisma.pan.dev/api/cloud/api-url


pcee_console_api_url="<https://<API_URL_FOUND_ABOVE>>

# Create access keys in the Prisma Cloud Enterprise Edition Console
# Example of a better way: pcee_console_api_url=$(vault kv get -format=json <secret/path> | jq -r '.<resources>')
pcee_accesskey="<ACCESS_KEY>"
pcee_secretkey="<SECRET_KEY>"


# No edits needed below this line

# formats above json correctly for the call below:

pcee_auth_body_single="
{
 'username':'${pcee_accesskey}', 
 'password':'${pcee_secretkey}'
}"

pcee_auth_body="${pcee_auth_body_single//\'/\"}"

# debugging to ensure jq and cowsay are installed

if ! type "jq" > /dev/null; then
  error_and_exit "jq not installed or not in execution path, jq is required for script execution."
fi


# debugging to ensure the variables are assigned correctly not required

if [ ! -n "$pcee_console_api_url" ] || [ ! -n "$pcee_secretkey" ] || [ ! -n "$pcee_accesskey" ]; then
  echo "pcee_console_api_url or pcee_accesskey or pcee_secret key came up null";
  exit;
fi

if [[ ! $pcee_console_api_url =~ ^(\"\')?https\:\/\/api[2-3]?\.prismacloud\.io(\"|\')?$ ]]; then
  echo "pcee_console_api_url variable isn't formatted or assigned correctly";
  exit;
fi

if [[ ! $pcee_accesskey =~ ^.{35,40}$ ]]; then
  echo "check the pcee_accesskey variable because it doesn't appear to be the correct length";
  exit;
fi

if [[ ! $pcee_secretkey =~ ^.{27,31}$ ]]; then
  echo "check the pcee_accesskey variable because it doesn't appear to be the correct length";
  exit;
fi


# Saves the auth token needed to access the CSPM side of the Prisma Cloud API to a variable named $pcee_auth_token

pcee_auth_token=$(curl -s --request POST \
                       --url "${pcee_console_api_url}/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${pcee_auth_body}" | jq -r '.token')


if [[ $(printf %s "${pcee_auth_token}") == null ]]; then
  echo "auth token not recieved, check to ensure access key and secret key assigned properly; also expiration date of the keys in the pcee console";
  exit;
else
  echo "auth token recieved";
fi

# Assigns the Summary results to var
overall_summary=$(curl --request GET \
     --url "${pcee_console_api_url}/v2/inventory?timeType=relative&timeAmount=1&timeUnit=month" \
     --header "x-redlock-auth: ${pcee_auth_token}" | jq -r '[{summary: "all_accounts",total_number_of_resources: .summary.totalResources, resources_passing: .summary.passedResources, resources_failing: .summary.failedResources, high_severity_issues: .summary.highSeverityFailedResources, medium_severity_issues: .summary.mediumSeverityFailedResources, low_severity_issues: .summary.lowSeverityFailedResources}]')


# Assigns the Compliance Posture results to var
compliance_summary=$(curl --request GET \
     --header "x-redlock-auth: ${pcee_auth_token}" \
     --url "${pcee_console_api_url}/compliance/posture?timeType=relative&timeAmount=1&timeUnit=month" | jq '[.complianceDetails[] | {framework_name: .name, number_of_policy_checks: .assignedPolicies, high_severity_issues: .highSeverityFailedResources, medium_severity_issues: .mediumSeverityFailedResources, low_severity_issues: .lowSeverityFailedResources, total_number_of_resources: .totalResources}]')


# Assigns the Service summary results to var
service_summary=$(curl --request GET \
  --url "${pcee_console_api_url}/v2/inventory?timeType=relative&timeAmount=1&timeUnit=month&groupBy=cloud.service&scan.status=all" \
  --header "x-redlock-auth: ${pcee_auth_token}" | jq '[.groupedAggregates[]]' | jq 'group_by(.cloudTypeName)[] | {(.[0].cloudTypeName): [.[] | {service_name: .serviceName, high_severity_issues: .highSeverityFailedResources, medium_severity_issues: .mediumSeverityFailedResources, low_severity_issues: .lowSeverityFailedResources, total_number_of_resources: .totalResources}]}')

echo "Ignore the JQ errors:"

echo -e "summary\n" >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv
printf %s ${overall_summary} | jq -r 'map({summary,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources,resources_passing,resources_failing}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv




echo -e "\ncompliance summary\n" >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv
printf %s ${compliance_summary} | jq -r 'map({framework_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources,number_of_policy_checks}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv


echo -e "\naws \n" >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv
printf %s ${service_summary} | jq -r '.aws' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv

echo -e "\nazure \n" >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv
printf %s ${service_summary} | jq -r '.azure' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv

echo -e "\ngcp \n" >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv
printf %s ${service_summary} | jq -r '.gcp' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv

echo -e "\noci \n" >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv
printf %s ${service_summary} | jq -r '.oci' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv

echo -e "\nalibaba_cloud \n" >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv
printf %s ${service_summary} | jq -r '.alibaba_cloud' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv

echo "report created here: $PWD/pcee_cspm_kpi_report_$(echo $(date  +%m_%d_%y)).csv" 
