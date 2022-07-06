$vcenter = "vcenter.ca"
$outputFile = "d:\All-RDMs-" + (get-date -Format yyyy-MM-dd-HHmm) + ".csv"

"Connecting vCenter servers ..."
Connect-VIServer $vcenter -AllLinked

$report = @()
$luns = @{}

"Getting VM(s). Be patient, this can take up to an hour ..."

$vms = Get-VM | Get-View
("Got " + $vms.Count + " VMs ...")

foreach($vm in $vms) {
     ("Processing VM " + $vm.Name + " ...")
     $ctl = $null
     $esx = $null
     write-host -NoNewLine "   Scanning VM's devices for RDMs ..."
     foreach($dev in $vm.Config.Hardware.Device){
          if(($dev.gettype()).Name -eq "VirtualDisk"){
               if(($dev.Backing.CompatibilityMode -eq "physicalMode") -or ($dev.Backing.CompatibilityMode -eq "virtualMode")){
                    if ($ctl -eq $null) {
                       " Found at least one ..."
                       "   Getting VM's SCSI controllers ..."
                       $ctl = Get-ScsiController -VM ($vm).Name
                    }
                    if ($esx -eq $null) {
                        write-host -NoNewLine "   Getting VM's host ..."
                        $esx = (Get-View $vm.Runtime.Host).Name
                        write-host (": " + $esx)
                    }
                    if ($luns[$esx] -eq $null) {
                        ("   Getting SCSI LUNs of host " + $esx + " ...")
                        $luns[$esx] = Get-ScsiLun -VmHost $esx -luntype disk
                    }
                    $row = "" | select VMName, GuestDevName, GuestDevID, VMHost, HDFileName, HDMode, HDsize, RuntimeName, CanonicalName
                    $row.VMName = $vm.Name
                    $row.GuestDevName = $dev.DeviceInfo.Label
                    $SCSIBus = ($ctl | where {$_.ExtensionData.Key -eq $dev.ControllerKey}).ExtensionData.BusNumber
                    $SCSIID = $dev.UnitNumber
                    $row.GuestDevID = "scsi" + $SCSIBus + ":" + $SCSIID
                    $row.VMHost = $esx
                    $row.HDFileName = $dev.Backing.FileName
                    $row.HDMode = $dev.Backing.CompatibilityMode
                    $row.HDSize = $dev.CapacityInKB
                    $lun = ($luns[$esx] | where {$_.ExtensionData.Uuid -eq $dev.Backing.LunUuid})
                    $row.CanonicalName = $lun.CanonicalName
                    $row.RuntimeName = $lun.RuntimeName
                    $report += $row
               }
          }
     }
     if ($ctl -eq $null) { " None found." }
}

"Exporting report data to $outputFile ..."
$report | Export-CSV -Path $outputFile
"All done."