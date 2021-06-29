# pcee_lunchbox_pov_api_cspm.sh
Creates the report needed to pull high level KPIs from the Prisma Cloud Enterprise Edition Console

# Last confirmed working 6.29.2021

# Assumptions

* You're using PRISMA CLOUD ENTERPRISE EDTION
* You're using an Ubuntu 20.04 VM to run this from
* You understand how to harden this script for production environments

  * The biggest suggestion here is to not save the script with your secret key and access key in it. A better way to do this might be to have a seperate script which exports those credentials as environmental variables. My goal with this script is to simplify the process for those who are learning to work with the Prisma Cloud Enterprise Edition API. 
  
* If you do decide to keep the keys in this script, then it's critical you:
  
   * Add it to your `.gitignore` (if using git) file and `chmod 700 container_licenses_and_packages.bash` between steps 3 and 4 so that others can't read, write, or excute it. 

# Instructions

* Step 1: Install jq `sudo apt-get install jq`
* Step 2: `git clone https://github.com/Kyle9021/pcee_lunchbox_pov_api_cspm`
* Step 3: `cd pcee_lunchbox_pov_api_cspm/`
* Step 4: `nano lunchbox_report.sh` and fill in the variables with the correct data from your console. 
* Step 5: `bash lunchbox_report.sh`
* Step 6: `ls` to see your report or go through the GUI to access the directory and open in excel/sheets

# Links to reference

* [Official JQ Documentation](https://stedolan.github.io/jq/manual/)
* [Exporting variables for API Calls and why I choose bash](https://apiacademy.co/2019/10/devops-rest-api-execution-through-bash-shell-scripting/)
* [PAN development site](https://prisma.pan.dev/)
