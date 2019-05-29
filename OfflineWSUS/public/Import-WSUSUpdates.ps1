function Import-WSUSUpdates {
    <#
    .SYNOPSIS
    Imports WSUS update metadata and binaries to a server.

    .DESCRIPTION
    Imports update metadata to a server from an export package file created on another WSUS server.
    This synchronizes the destination WSUS server without using a network connection.

    See https://docs.microsoft.com/de-de/security-updates/windowsupdateServices/18127395 for more information.

    .PARAMETER ComputerName
        The target computer that will perform the import. Defaults to localhost.

    .PARAMETER LogFile
         The path and file name of the log file.

    .PARAMETER Xml
        Path to the import approval metadata Xml.

    .PARAMETER ContentPath
        Path of Path wsuscontent (if they pass the wsuscontent folder in the path, auto strip it?)

    .PARAMETER ContentDestination
        Path of destination wsuscontent. Why is this beneficial? I don't use the product,
        have no idea and would like to know. So would be good to include in help.

    .PARAMETER WsusUtilPath
        The path to wsusutil.exe. Defaults to "C:\Program Files\Update Services\Tools\WsusUtil.exe"

    .INPUTS

    .OUTPUTS
    WARNING: [14:22:31][Import-WSUSUpdates] Incomplete or invalid parameters specified. See below for correct format and
options:   Imports update metadata (but not content files, approvals, or server settings) to this server from an export
 package file created on another WSUS server. This synchronizes this WSUS server without using a network connection.
import <package> <log file>  <package>:          Path and filename of the package CAB file (or GZIP file with an
.xml.gz      extension) to import     <log file>:       Path and filename of the log file to create

    .EXAMPLE

    .LINK

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter()]
        [string]
        $ComputerName = $env:ComputerName,
        [Parameter(Mandatory)]
        [System.IO.FileInfo]
        $Path,
        [Parameter()]
        [string]
        $Xml = (Get-ChildItem -Path $Path | where name -like "*.xml.gz" | select -ExpandProperty FullName),
        [Parameter()]
        [string]
        $LogFile = (Get-ChildItem -Path $Path | where name -like "*.log" | select -ExpandProperty FullName),
        [Parameter()]
        [switch]
        $ImportApprovalStatus
    )

    begin {
        $scriptelapsed = [System.Diagnostics.Stopwatch]::StartNew()
    }

    process {
        #Getting WSUS info
        $WSUSSetup = Get-WSUSSetupInfo -ComputerName $ComputerName
        $PathFileCount = Get-ChildItem -Path $Path -File -Recurse | Measure-Object | % { $_.Count }
        $Exclude = Get-ChildItem -recurse $WSUSSetup.WSUSContentPath
        $Service = Get-Service -Name "WsusService" -ErrorAction SilentlyContinue
        $WSUSUtilArgList = @(
            "import",
            "$Xml",
            "$LogFile"
        )

        #Testing paths
        if (($WSUSSetup.WSUSUtilPathExists -eq $false) -or ($WSUSSetup.WSUSContentPathExists -eq $false)) {
            Stop-PSFFunction -Message "Paths do not exist" -ErrorRecord $_
            return
        }

        #Stopping wsus Service if not stopped already
        if ($Service.Status -ne "Stopped") {
            Write-PSFMessage -Message "Stopping $($Service.DisplayName) on $ComputerName" -Level Important
            $Service.Stop()
            $Service.WaitForStatus('Stopped', '00:00:20')
            if ($Service.Status -eq "Stopped") {
                Write-PSFMessage -Message "$($Service.DisplayName) is now $($Service.Status)" -Level Important
            }
            else {
                Stop-PSFFunction -Message "Could not stop $($Service.DisplayName)" -Continue
            }
        }
        elseif ($Service.Status -eq "Stopped") {
            Write-PSFMessage -Message "$($Service.DisplayName) was already in a stopped state, continuing with import." -Level Important
        }
        else {
            Stop-Function -Continue -Message "WSUS Service is in an unknown state" -ErrorRecord $_ -EnableException $true###############################################
            return
        }

        #Import start

        Write-PSFMessage -Message "Starting import" -Level Important

        Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
        try {
            Copy-Item -Path "$Path\wsuscontent\*" -Destination $WSUSSetup.WSUSContentPath -Recurse -Force -Exclude $Exclude -ErrorAction Stop
        }
        catch {
            Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -EnableException $true###############################################
            return
        }
        Write-PSFMessage -Message "File copy complete" -Level Important
        
        Write-PSFMessage -Message "Starting import of WSUS Metadata, this will take a while." -Level Important

        try {
            $ImportProcess = & $WSUSSetup.WSUSUtilPath $WSUSUtilArgList #| Out-Null
            $WSUSUtilout = Select-String -Pattern "successfully imported" -InputObject $ImportProcess -ErrorAction Stop
            if ($WSUSUtilout -like "*success*") {
                Write-PSFMessage -Message "Import was successful" -Level Important
            }
            <#elseif ($WSUSUtilout -notlike "*success*") {
                Stop-PSFFunction -Message "Metadata import was unsuccessful" -ErrorRecord $_
            }
            else {
                Stop-PSFFunction -Message "Could not determine output of import" ###############################################
                return
            }#>
        }
        catch {
            #Write-PSFMessage -Message "Could not import metadata" -Level Critical -ErrorRecord $_
            Stop-PSFFunction -Message "Could not import metadata" -ErrorRecord $_ -EnableException $true
        }

        Write-PSFMessage -Message "Starting $($Service.DisplayName) service on $ComputerName" -Level Important

        if ($Service.Status -ne "Running") {
            $Service.Start()
            $Service.WaitForStatus('Running', '00:00:30')
            Write-PSFMessage -Message "$($Service.DisplayName) service is now running on $ComputerName" -Level Important
        }
        else {
            Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -Continue
        }

        if ($ImportApprovalStatus) {
            Write-PSFMessage -Message "Importing update approval status." -Level Important
            $ApprovalStatus = Import-CSV -Path (Get-ChildItem -Path $Path | where name -like "*.csv" | select -ExpandProperty FullName)
            $ApprovalStatus | where action -eq "Install" | Approve-PSWSUSUpdate
            $ApprovalStatus | where action -eq "NotApproved" | Deny-WsusUpdate
        }

        [pscustomobject]@{
            ComputerName    = $ComputerName
            Action          = "Import"
            Result          = "Success" # can you add record numbers or any other useful info?############################################################################################################################
            FileCount       = $PathFileCount############################################################################################################################
            ElapsedTIme     = [math]::Round($scriptelapsed.Elapsed.TotalSeconds, 2)
            ObjectsImported = $null
        }
    }
    End {

    }
}
<#
        if ($ComputerName -eq $env:ComputerName) {
            $WSUSSetup = Get-WSUSSetupInfo
            $Service = Get-Service -name WsusService -ErrorAction SilentlyContinue
            $WSUSUtilArgList = @(
                "import",
                "$Xml",
                "$LogFile"
            )

            if (($WSUSSetup.WSUSUtilPathExists -eq $false) -or ($WSUSSetup.WSUSContentPathExists -eq $false)) {
                Stop-PSFFunction -Message "Paths do not exist" -ErrorRecord $_
                return
            }
        }
        else {
            $WSUSSetup = Get-WSUSSetupInfo -ComputerName $ComputerName
            $Service = Get-Service -ComputerName $ComputerName -name WsusService -ErrorAction SilentlyContinue
            $WSUSUtilArgList = @(
                "import",
                "$Xml",
                "$LogFile"
            )

            if (($WSUSSetup.WSUSUtilPathExists -eq $false) -or ($WSUSSetup.WSUSContentPathExists -eq $false)) {
                Stop-PSFFunction -Message "Paths do not exist" -ErrorRecord $_
                return
            }
        }


        #oldformat
        ############################################################################################################################
        ############################################################################################################################
        ############################################################################################################################
        #$WSUSSetup = Get-WSUSSetupInfo

        #$WSUSSetup = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup"
        #$ContentDestination = ($WSUSSetup.ContentDir + "\wsuscontent")
        ##$WsusUtilPath = ($WSUSSetup.TargetDir + "Tools\WsusUtil.exe")
        #$Xml = Get-ChildItem -Path $Path | where name -like "*.xml.gz" | select -ExpandProperty FullName
        #$LogFile = Get-ChildItem -Path $Path | where name -like "*.log" | select -ExpandProperty FullName
        #$Service = Get-Service -ComputerName $ComputerName -name WsusService -ErrorAction SilentlyContinue
        #$Exclude = Get-ChildItem -recurse $ContentDestination
        #$WSUSUtilArgList = @(
        #    "import",
        #    "$Xml",
        #    "$LogFile"
        #)

        #going to rewrite all of this without psframework

        if (-not (Test-Path $WsusUtilPath)) {
            ############################################################################################################################
            Stop-PSFFunction -Message "$WsusUtilPath does not exist"
            return
        }

        Write-PSFMessage -Message "Starting import" -Level Important

        if ($Service.Status -ne "Stopped") {
            Write-PSFMessage -Message "Stopping $($Service.DisplayName) Service on $ComputerName" -Level Important
            $Service.Stop()
            $Service.WaitForStatus('Stopped', '00:00:20')
            if ($Service.Status -eq "Stopped") {
                Write-PSFMessage -Message "$($Service.DisplayName) is now $($Service.Status)" -Level Important
            }
            else {
                Stop-PSFFunction -Message "Could not stop $($Service.DisplayName)" -Continue
            }
        }
        elseif ($Service.Status -eq "Stopped") {
            if (Test-Path -Path $ContentDestination) {
                Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
                try {
                    Copy-Item -Path "$Path\WsusContent\*" -Destination $ContentDestination -Recurse -Force -Exclude $Exclude -ErrorAction Stop
                }
                catch {
                    Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -EnableException
                }
            }
            try {
                Write-PSFMessage -Message "Starting import of WSUS Metadata, this will take a while." -Level Important
                $ImportProcess = & $WsusUtilPath $WSUSUtilArgList
                $WSUSUtilout = Select-String -Pattern "successfully imported" -InputObject $ImportProcess -ErrorAction Stop
                if ($WSUSUtilout -like "*success*") {
                    Write-PSFMessage -Message "Import was successful" -Level Important
                }
            }
            catch {
                #Write-PSFMessage -Message "Could not import metadata" -Level Critical -ErrorRecord $_
                Stop-PSFFunction -Message "Could not import metadata" -ErrorRecord $_ -EnableException
            }
            if ($Service.Status -ne "Running") {
                Write-PSFMessage -Message "Starting $($Service.DisplayName) Service on $ComputerName" -Level Important
                $Service.Start()
                $Service.WaitForStatus('Running', '00:00:30')
            }
            else {
                Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -Continue
            }
            if ($ImportApprovalStatus) {
                $ApprovalStatus = Import-CSV -Path (Get-ChildItem -Path $Path | where name -like "*.csv" | select -ExpandProperty FullName)
                $ApprovalStatus | where action -eq "Install" | Approve-PSWSUSUpdate
                $ApprovalStatus | where action -eq "NotApproved" | Deny-WsusUpdate


            }
        }
        else {
            Stop-Function -Continue -Message "WSUS Service is in an unknown state" -ErrorRecord $_
            return
        }#>

        
