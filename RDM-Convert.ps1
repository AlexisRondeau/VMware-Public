#==========================================================================================================================
# Script:		RDM-Convert.ps1
# Creator:		Alexis Rondeau
# Date:			2019/08/14
#
# Description:	Powershell script to convert Physical RDM to VMDK
#
# -------------------------------------------------------------------------------------------------------------------------
#
# Modification:		2019/09/05
#			
# -------------------------------------------------------------------------------------------------------------------------
#
# Pre-requisite:    VMware PowerCli 11.0 or later
#					Appropriate Rights in vCenter
#
# -------------------------------------------------------------------------------------------------------------------------
#@  Usage:
#@
#@    XXXXXXXX.ps1 .... [ Common Parameters ]
#@
#@  Paramaters:
#@
#@
#@  Common parameters:
#@
#@    [ -Help ]     : Display help
#@
#@  Examples:
#@
#@    XXXXXXXX.ps1
#@    XXXXXXXX.ps1 -Help
#@    
#==========================================================================================================================

#------------------------------------------#
# 			Script Parameters
#------------------------------------------#
PARAM(
    [String]$vm,
    [String]$NetappID    
)

#------------------------------------------#
#  		   	PowerShell SnapIn
#------------------------------------------#

If (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
Add-PSSnapin VMware.VimAutomation.Core
}

#------------------------------------------#
#   Global Variables and Initialisation
#------------------------------------------#

$vc = "" #vCenter FQDN
if($cred -eq ""){
    $cred = Get-Credential -Message "Please provide vCenter credentials" #vCenter credentials with sufficient permissions
}
   # $vm = "rdm-vm"

#**************************************************************************************************************************
#	   											  Main Procedure
#**************************************************************************************************************************

# Connect to vCenter 
Write-Host "Connecting to vCenter"
$rc = Connect-VIServer $vc -Credential $cred -Force:$true

IF ($rc) {
    Write-Host "Getting VMs informations"
$target_VM = Get-VM $vm
$target_RDMs = Get-HardDisk -VM $target_VM -DiskType:RawPhysical | Where-Object{$_.ScsiCanonicalName -ilike "*$NetappID"}
$target_DS = Get-Datastore -Name "Local_VMFS2" #Datastore where the RDM will be converted to a VMDK
IF ($target_RDMs -ne "") {	
    #Stop/Shutdown VM
    if($target_VM.ExtensionData.Guest.ToolsRunningStatus -eq "guestToolsNotRunning" -and $target_VM.PowerState -eq "PoweredOff") {
        Write-Host "VM already shutdown"
    }ELSEIF($target_VM.ExtensionData.Guest.ToolsRunningStatus -ne "guestToolsNotRunning" -and $target_VM.PowerState -eq "PoweredOn"){
        Write-Host "Shutting down guest on VM" $target_VM.Name
        Shutdown-VMGuest -VM $vm -Confirm:$false
    }ELSEIF($target_VM.ExtensionData.Guest.ToolsRunningStatus -ne "guestToolsRunning" -and $target_VM.PowerState -eq "PoweredOn"){
        Write-Host "Powering off VM" $target_VM.Name
        Stop-VM -VM $vm -Confirm:$false
    }ELSE{
        Write-Warning "VM is not in an healthy state, exiting"
        EXIT
    }
    
    #---------------------------------------------------------------------------#
    # Get RDM information and Proper Configuration
    #---------------------------------------------------------------------------#	
    foreach($target_RDM in $target_RDMs){
        Write-Host "Converting RDM to VMDK, current RDM:" $target_RDM.Name "LUN :" $target_RDM.ScsiCanonicalName.Substring(32)
        Move-HardDisk -HardDisk $target_RDM -StorageFormat:Thick -Datastore $target_DS -Confirm:$false -WhatIf:$false | Out-Null
        Write-Host "Set Persistence on VMDK"
        Get-HardDisk -VM $target_VM -Name $target_RDM.Name | Set-HardDisk -Persistence "Persistent" -Confirm:$false -WhatIf:$false
        }
        #Remove-HardDisk -DeletePermanently:$true -HardDisk $target_RDM
        #New-HardDisk -DiskType:RawVirtual
        
    }
    
} ELSE {
    Write-Warning "Unable to convert RDM to VMDK.. Script will exit"
    EXIT
}

Disconnect-VIServer -Confirm:$false

#**************************************************************************************************************************
#	   											End Main Procedure
#**************************************************************************************************************************
