#==========================================================================================================================
# Script:		Validate_VMDK_Location.ps1
# Creator:		Alexis Rondeau
# Date:			2019/09/23
#
# Description:	Powershell script to validate if Temp drive (T:) reside in proper Datastore and no other VMDKs.
#
# -------------------------------------------------------------------------------------------------------------------------
#
# Modification:		2019/09/26
#			
# -------------------------------------------------------------------------------------------------------------------------
#
# Pre-requisite:    VMware PowerCli 11.0 or later
#					Appropriate Rights in vCenter
#                   Appropriate Rights on Windows OS
#                   DiskUUID = True
#
# -------------------------------------------------------------------------------------------------------------------------
#==========================================================================================================================

#------------------------------------------#
#   Global Variables and Initialisation
#------------------------------------------#

$vc = "car-vc-01.bhe.corp" #vCenter FQDN or IP

if($cred.UserName -eq $null){
    $cred = Get-Credential -Message "Please provide vCenter credentials" #vCenter credentials with sufficient permissions
}
if($OS_cred.UserName -eq $null){
    $OS_cred = Get-Credential -Message "Please provide Windows credentials" #Guest OS credentials with sufficient permissions
}

$script = "(Get-Partition -DriveLetter T | get-disk).SerialNumber"

#**************************************************************************************************************************
#	   											  Main Procedure
#**************************************************************************************************************************

# Connect to vCenter 
Write-Host "Connecting to vCenter"
$rc = Connect-VIServer $vc -Credential $cred -Force:$true


IF ($rc) {
    Write-Host "Getting VMDKs informations"
    $target_DS = Get-Datastore -Name "Local_VMFS1" #Datastore where the TEMP disk reside
    $target_VMDK = $target_DS | Get-VM | Get-HardDisk

        foreach($vmdk in $target_VMDK){
            $OS_ScriptOutput = $null
            $OSdisk_SerialNumber = $null
            $vmdk_serial = $vmdk.ExtensionData.Backing.Uuid.replace(' ','').replace('-','')
            #Validate VMware tools and Guest OS
            if(($vmdk.Parent.ExtensionData.Guest.ToolsRunningStatus -eq "guestToolsRunning") -and ($vmdk.Parent.GuestId -ilike "*win*")){
                #Get Windows Drive Letter T serial number via VMware Tools
                $OS_ScriptOutput = Invoke-VMScript -VM $vmdk.Parent -ScriptText $script -ScriptType:Powershell -GuestCredential $OS_cred
            }elseif (($vmdk.Parent.ExtensionData.Guest.ToolsRunningStatus -ne "guestToolsRunning") -and ($vmdk.Parent.GuestId -ilike "*win*")) {
                #Get Windows Drive Letter T, serial number via VMI
                $regex = [Regex]::new("(?<=\\\\\\\\.\\\\).+\w")
                $logtopart=Get-WmiObject -Class Win32_LogicalDiskToPartition -computername $vmdk.Parent
                $disktopart=Get-WmiObject Win32_DiskDriveToDiskPartition -computername $vmdk.Parent
                $WinDisks = Get-WmiObject -Class Win32_DiskDrive -computername $vmdk.Parent
                
                $temp_vol = $logtopart | Where-object{$_.Dependent -ilike "*T:*"}
                $temp_disk = $disktopart | Where-object{$_.Dependent -eq $temp_vol.Antecedent}
                $match = $regex.Match($temp_disk.Antecedent)
                $temp_vmdisk = $WinDisks | Where-object{$_.DeviceID -eq "\\.\$match"} 
                
                $OSdisk_SerialNumber = $temp_vmdisk.SerialNumber
            }

            if($OS_ScriptOutput -ne $null){
                #validate serial number Invoke-VMscript against UUID from vCenter
                $OSdisk_SerialNumber = ($OS_ScriptOutput.ScriptOutput -split '\n')[0]
                
                    if($OSdisk_SerialNumber.Trim() -ne $vmdk_serial){
                        write-host -ForegroundColor Yellow -BackgroundColor Red "Not a SQL Temp disk, please move Harddisk" $vmdk.Name "from" $vmdk.Parent
                    }
                }elseif($OSdisk_SerialNumber -ne $null){
                    if($OSdisk_SerialNumber -ne $vmdk_serial){
                        write-host -ForegroundColor Yellow -BackgroundColor Red "Not a SQL Temp disk, please move Harddisk" $vmdk.Name "from" $vmdk.Parent
                    }
                }else{
                Write-host -ForegroundColor Red "Unable to run command on Guest VM via VMware tools or WMI on VM" $vmdk.Parent ", please validate if VM belongs to the datastore" $target_DS.Name
            }
        }

}

Disconnect-VIServer $vc -Confirm:$false

#**************************************************************************************************************************
#	   											End Main Procedure
#**************************************************************************************************************************