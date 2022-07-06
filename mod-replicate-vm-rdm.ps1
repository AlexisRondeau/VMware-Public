#==========================================================================================================================
# Module:		mod-replicate-vm-rdm.ps1
# Creator:		Alexis Rondeau
# Date:			2014/11/07
#
# Description:	This module will replicate a VM RDM configuration from one VM to a target VM.
#				If a SCSI controller need to the added, the target VM must be powered off.
#
# -------------------------------------------------------------------------------------------------------------------------
#
# Modification:		YYYY/MM/DD
#			
# -------------------------------------------------------------------------------------------------------------------------
#
# Pre-requisite:	PowerShell 2.0
#
# -------------------------------------------------------------------------------------------------------------------------
#
# Parameter(s):		fromvm			[string]		Source Virtual Machine name
#					tovm			[string]		Target Virtual Machine Name
# -------------------------------------------------------------------------------------------------------------------------
#
# Return:			result			(boolean)		Operation result
#						$true		Sucessful
#						$false		Not Successful
# -------------------------------------------------------------------------------------------------------------------------

FUNCTION replicate-vm-rdm () {

	#------------------------------------------#
	# Module Input Parameter(s)
	#------------------------------------------#

	PARAM(
		[String]$fromvm,
		[String]$tovm
	)

	#------------------------------------------#
	# Variable Initialisation
	#------------------------------------------#

	$fromvmrdm = Get-HardDisk -VM $fromvm -DiskType rawPhysical
	$tovmrdmlist = Get-HardDisk -VM $tovm -DiskType rawPhysical | Select -ExpandProperty FileName
	$vmtochange = Get-VM $tovm

	#------------------------------------------#
	# Module Action(s)
	#------------------------------------------#
	
	#Validate if the VM is powered off
	IF (-not(Get-VM $vmtochange).PowerState -eq "PoweredOff") {
		Write-Error "Virtual Machine need to be Powered Down to perform this action, script will now exit"
		EXIT

	} ELSE {			
	
		FOREACH ($rdmdisk in $fromvmrdm) {

			IF ($tovmrdmlist -notcontains $rdmdisk.Filename) {

				$ctrl = Get-ScsiController -HardDisk $rdmdisk
				$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
				$spec.DeviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec 
				$spec.deviceChange[0].device += $ctrl.ExtensionData 
				$spec.deviceChange[0].device.Key = -101
				$spec.deviceChange[0].operation = "add"

				$spec.DeviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec
				$spec.deviceChange[1].device += $rdmdisk.ExtensionData
				$spec.deviceChange[1].device.Key = -102
				$spec.deviceChange[1].device.ControllerKey = -101
				$spec.deviceChange[1].operation = "add"
				Write-Progress "Raw Device Mapping" "Adding $rdmdidk on $tovm"
				$vmtochange.ExtensionData.ReconfigVM($spec) | Out-Null
			}
		}
	}

	RETURN $result
	
}