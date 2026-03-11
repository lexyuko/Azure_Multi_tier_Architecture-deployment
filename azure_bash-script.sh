#!/bin/bash
# ============================================================
# PROJECT: Azure Multi-Tier VNet Deployment Script
# Tech-Crush Capstone — Group 1
# ============================================================

# ============================================================
# Resource deliverable names
# ============================================================
Resource="Tech-Crush_Capstone"
location="denmarkeast"
vnet_name="capstone"
subnet1_name="Web"
subnet2_name="App"
subnet3_name="DB"
nsg_name="capstone-nsg"
vm_name1="WebVM"
vm_name2="AppVM"
vm_name3="DBVM"
OS="Canonical:ubuntu-24_04-lts:server:latest"
username="adminuser"

# ========================================================================
# STEP 1:- CREATE SSH KEY PAIRS NECESSARY FOR SSH HOPPING (if not already present)
# generates ssh keys and the keysgoes on all # vms
# ========================================================================

 if [ ! -f ~/.ssh/id_rsa ]; then 
    echo ">>> NO SSH KEY PRESENT - Generating New Keys..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo ">>> SSH keys Generated at ~/.ssh/id_rsa"
 else
    echo ">>> SSH keys Already exists at ~/.ssh/id_rsa"
 fi

# ============================================================
#STEP 2 :- DEPLOY AND CONFIGURE
# ============================================================

# ============================================================
# CREATE RESOURCE GROUP
# ============================================================
az group create  --name $Resource --location $location

# ============================================================
# CREATE VNET AND WEB SUBNET
# ============================================================
az network vnet create  \
 --resource-group $Resource \
 --name $vnet_name \
 --address-prefix 10.0.0.0/16 \
 --subnet-name $subnet1_name \
 --subnet-prefix 10.0.1.0/24

# ============================================================
# CREATE APP SUBNET
# ============================================================
az network vnet subnet create \
 --resource-group $Resource \
 --vnet-name $vnet_name \
 --name $subnet2_name \
 --address-prefix 10.0.2.0/24

# ============================================================
# CREATE DB SUBNET
# ============================================================
az network vnet subnet create \
 --resource-group $Resource \
 --vnet-name $vnet_name \
 --name $subnet3_name \
 --address-prefix 10.0.3.0/24

# ============================================================
 # Create public IPs for all VM 
 # ============================================================
az network public-ip create \
  --resource-group $Resource \
  --name WebVM-pip \
  --sku Standard \
  --version IPv4 \
  --allocation-method Static

# ============================================================
# PROVISION LINUX VM — WEB SUBNET
# ============================================================
az vm create \
 --resource-group $Resource \
 --name $vm_name1 \
 --image $OS \
 --size Standard_B1s \
 --vnet-name $vnet_name \
 --subnet $subnet1_name \
 --public-ip-address WebVM-pip \
 --admin-username $username \
 --generate-ssh-keys

# ============================================================
# PROVISION LINUX VM — APP SUBNET
# ============================================================
az vm create \
 --resource-group $Resource \
 --name $vm_name2 \
 --image $OS \
 --size Standard_B1s \
 --vnet-name $vnet_name \
 --subnet $subnet2_name \
 --admin-username $username \
 --generate-ssh-keys

# ============================================================
# PROVISION LINUX VM — DB SUBNET
# ============================================================
 az vm create \
 --resource-group $Resource \
 --name $vm_name3 \
 --image $OS \
 --size Standard_B1s \
 --vnet-name $vnet_name \
 --subnet $subnet3_name \
 --admin-username $username \
 --generate-ssh-keys

# ============================================================
# OPEN PORT 22 FOR SSH TESTING (ALL VMs)
# ============================================================
 az vm open-port \
 --resource-group $Resource \
 --name $vm_name1 \
 --port 22

  az vm open-port \
 --resource-group $Resource \
 --name $vm_name2 \
 --port 22

  az vm open-port \
 --resource-group $Resource \
 --name $vm_name3 \
 --port 22
 
# ============================================================
# CREATE NSGs — ONE PER SUBNET
# ============================================================
 az network nsg create\
  --resource-group $Resource\
  --name $subnet1_name \
  --location $location

   az network nsg create\
  --resource-group $Resource\
  --name $subnet2_name \
  --location $location

   az network nsg create\
  --resource-group $Resource\
  --name $subnet3_name \
  --location $location

# ============================================================
# NSG RULE: ALLOW SSH INBOUND (ALL SUBNETS)
# ============================================================
 az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet1_name \
 --name AllowSSHInbound \
 --priority 100 \
 --access allow \
 --direction Inbound \
 --destination-port-ranges 22 \
 --protocol Tcp

 az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet2_name \
 --name AllowSSHInbound \
 --priority 110 \
 --access allow \
 --direction Inbound \
 --destination-port-ranges 22 \
 --protocol Tcp

 az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet3_name \
 --name AllowSSHInbound \
 --priority 120 \
 --access allow \
 --direction Inbound \
 --destination-port-ranges 22 \
 --protocol Tcp
 
# ============================================================
# NSG RULE: ALLOW HTTP (WEB TIER — PORT 80/443)
# ============================================================
 az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet1_name \
 --name AllowHTTPInbound \
 --priority 130 \
 --access Allow \
 --direction Inbound \
 --destination-port-ranges 80 443 \
 --protocol Tcp

# ============================================================
# NSG RULE: ALLOW WEB → APP (APP TIER ACCEPTS FROM WEB ONLY)
# ============================================================
 az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet2_name \
 --name AllowWebTOApp \
 --priority 140 \
 --access Allow \
 --direction Inbound \
 --source-address-prefixes 10.0.1.0/24 \
 --destination-address-prefixes 10.0.2.0/24 \
 --destination-port-ranges 8080 \
 --protocol Tcp

# ==========================================================================
# NSG RULE: ALLOW APP → DB (DB TIER ACCEPTS FROM APP ONLY) DATABASE = MONGODB 
# ============================================================================
az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet3_name \
 --name AllowAppToDB \
 --priority 150 \
 --access Allow \
 --direction Inbound \
 --source-address-prefixes 10.0.2.0/24 \
 --destination-address-prefixes 10.0.3.0/24 \
 --destination-port-ranges 27017 \
 --protocol Tcp

# ============================================================
# NSG RULE: DENY WEB → DB (BLOCK DIRECT ACCESS)
# ============================================================
 az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet1_name \
 --name DenyWebToDB \
 --priority 160 \
 --access Deny \
 --direction Outbound \
 --protocol Icmp \
 --source-address-prefixes 10.0.1.0/24 \
 --destination-address-prefixes 10.0.3.0/24 

  az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet1_name \
 --name DenyWebToDB \
 --priority 170 \
 --access Deny \
 --direction Inbound \
 --protocol Icmp \
 --source-address-prefixes 10.0.3.0/24 \
 --destination-address-prefixes 10.0.1.0/24


  az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet3_name \
 --name DenyDBTOWeb \
 --priority 180 \
 --access Deny \
 --direction Outbound \
 --protocol Icmp \
 --source-address-prefixes 10.0.3.0/24 \
 --destination-address-prefixes 10.0.1.0/24

 az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet3_name \
 --name DenyDBTOWeb \
 --priority 190 \
 --access Deny \
 --direction Inbound \
 --protocol Icmp \
 --source-address-prefixes 10.0.1.0/24 \
 --destination-address-prefixes 10.0.3.0/24 

# ============================================================
# NSG RULE: ALLOW ICMP WEB ↔ APP ↔ DB (PING TESTS)
# ============================================================
  az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet2_name \
 --name AllowPingsWebToApp \
 --priority 200 \
 --access Allow \
 --direction Inbound \
 --protocol Icmp \
 --source-address-prefixes 10.0.1.0/24 \
 --destination-address-prefixes 10.0.2.0/24 


  az network nsg rule create \
 --resource-group $Resource \
 --nsg-name $subnet2_name \
 --name AllowPingsDBToApp \
 --priority 210 \
 --access Allow \
 --direction Inbound \
 --protocol Icmp \
 --source-address-prefixes 10.0.3.0/24 \
 --destination-address-prefixes 10.0.2.0/24 

# ============================================================
# ASSOCIATE NSGs WITH SUBNETS
# ============================================================
 az network vnet subnet update\
 --resource-group $Resource \
 --vnet-name $vnet_name \
 --name $subnet1_name \
 --network-security-group $subnet1_name

 az network vnet subnet update\
 --resource-group $Resource \
 --vnet-name $vnet_name \
 --name $subnet2_name \
 --network-security-group $subnet2_name

 az network vnet subnet update\
 --resource-group $Resource \
 --vnet-name $vnet_name \
 --name $subnet3_name \
 --network-security-group $subnet3_name

# ============================================================
# START VMs
# ============================================================
az vm start \
 --resource-group $Resource\
 --name $vm_name1

 az vm start \
 --resource-group $Resource\
 --name $vm_name2

az vm start \
 --resource-group $Resource\
 --name $vm_name3

 # ==============================================================================
 #STEP3 :- CAPTURE IP ADDRESS AND SETUP SSH HOPPING(REQUIRED FOR NETWORK SECURITY)
 # ==============================================================================

 # ============================================================
 # Capture webVM private/public IPs after deployment:
 # assign IP's into variables
 # ============================================================
 echo ""
 echo "Fetching VM IP addresses"

 webVm_Public_IP=$(
    az vm list-ip-addresses \
 --resource-group $Resource \
 --name $vm_name1 \
 --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
  --output tsv
 )

 webVm_Private_IP=$(
    az vm list-ip-addresses \
 --resource-group $Resource \
 --name $vm_name1 \
 --query "[0].virtualMachine.network.privateIpAddresses[0]" \
  --output tsv
 )

 appVm_Private_IP=$(
    az vm list-ip-addresses \
 --resource-group $Resource \
 --name $vm_name2 \
 --query "[0].virtualMachine.network.privateIpAddresses[0]" \
  --output tsv
 )

 dbVm_Private_IP=$(
    az vm list-ip-addresses \
 --resource-group $Resource \
 --name $vm_name3 \
 --query "[0].virtualMachine.network.privateIpAddresses[0]" \
  --output tsv
 )

 echo ""
 echo "================================================"
 echo " DEPLOYMENT COMPLETE -- VM IP SUMMARY"
 echo "================================================"
 echo " WebVM Public IP  : $webVm_Public_IP"
 echo " WebVM Private IP : $webVm_Private_IP"
 echo " APPVM Private IP : $appVm_Private_IP"
 echo " DBVM Private IP  : $dbVm_Private_IP"
 echo  "================================================"

 # ============================================================
 # CREATE SSH LOCAL AGENT(for SSH hop forwarding)
 # ============================================================
 echo ""
 echo ">>> Starting SSH Agent and adding key ..."
 eval "$(ssh-agent -s)"
 ssh-add ~/.ssh/id_rsa
 echo ">>> ssh Key added to agent -agent forwarding ready"



# =============================================================================
# VERIFICATION STEPS (Manual — run after deployment and ssh setup is completed)
# =============================================================================
echo ""
echo "============================================================"
echo "  SSH HOP COMMANDS — run these manually in your terminal"
echo "============================================================"
echo ""
echo "  # STEP A: SSH into WebVM (entry point)"
echo "  ssh -A -i ~/.ssh/id_rsa $username@$webVm_Public_IP"
echo ""
echo "  # STEP B: From inside WebVM — hop to AppVM"
echo "  ssh $username@$appVm_Private_IP"
echo ""
echo "  # STEP C: From inside AppVM — hop to DBVM"
echo "  ssh $username@$dbVm_Private_IP"

echo "FROM WebVM"
echo "ping -c 4 $appVm_Private_IP # (APP) → SHOULD SUCCEED"  
echo "ping -c 4 $dbVm_Private_IP  # (DB)   → SHOULD FAIL" 
echo ""    
echo "FROM AppVM" 
echo " ping -c 4 $webVm_Private_IP  #  (Web)  → SHOULD SUCCEED " 
echo " ping -c 4 $dbVm_Private_IP #  (DB)  → SHOULD SUCCEED " 
echo ""
echo "FROM DBVM"  
echo "ping -c 4 $appVm_Private_IP # (APP) → SHOULD SUCCEED" 
echo " ping -c 4 $webVm_Private_IP  # (Web)  → SHOULD FAIL "  

# ============================
# DONE
# ============================

