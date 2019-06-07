function Import-WSUSUpdatePackage {
    <#
    .SYNOPSIS
    Imports WSUS update metadata, binaries, and approval status to a server.
    
    .DESCRIPTION
    Imports update metadata to a server from an export package file created on another WSUS server.
    This synchronizes the destination WSUS server without using a network connection.

    See https://docs.microsoft.com/de-de/security-updates/windowsupdateServices/18127395 for more information.
    
    .PARAMETER ComputerName
    The target computer that will perform the import. Defaults to localhost.
    
    .PARAMETER Path
    Path to WSUS export
    
    .PARAMETER Xml
    Path to the import approval metadata Xml.
    
    .PARAMETER LogFile
    The path and file name of the log file.
    
    .PARAMETER DeclineStatusPath
    Path to csv for declined status. Will try to find it automatically
    
    .PARAMETER ApprovalStatusPath
    Path to csv for approval status. Will try to find it automatically
    
    .PARAMETER ImportApprovalStatus
    Switch to import approvals
    
    .PARAMETER ImportDeclinedStatus
    Switch to import declined status
    
    .PARAMETER FirstRun
    not sure
    
    .EXAMPLE
    Import-WSUSUpdatePackage
    
    .NOTES
    General notes
    #>
    
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter()]
        [string]
        $ComputerName = $env:ComputerName,
        [Parameter(Mandatory)]
        [ValidateScript( { Test-Path -Path $_ })]
        [System.IO.FileInfo]
        $Path,
        [Parameter()]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]
        $Xml = (Get-ChildItem -Path $Path | where name -like "*.xml.gz" | select -ExpandProperty FullName),
        [Parameter()]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]
        $LogFile = (Get-ChildItem -Path $Path | where name -like "*.log" | select -ExpandProperty FullName),
        [Parameter()]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]
        $DeclineStatusPath = (Get-ChildItem -Path $Path | where name -like "*ApprovalStatus.csv" | select -ExpandProperty FullName),
        [Parameter()]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]
        $ApprovalStatusPath = (Get-ChildItem -Path $Path | where name -like "*DeclinedStatus.csv" | select -ExpandProperty FullName),
        [Parameter()]
        [switch]
        $ImportApprovalStatus,
        [Parameter()]
        [switch]
        $ImportDeclinedStatus,
        # Parameter help description
        [Parameter()]
        [switch]
        $FirstRun
    )

    begin {
        $scriptelapsed = [System.Diagnostics.Stopwatch]::StartNew()
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
    }

    process {
        #Testing paths
        if (($WSUSSetup.WSUSUtilPathExists -eq $false) -or ($WSUSSetup.WSUSContentPathExists -eq $false)) {
            Stop-PSFFunction -Message "Paths do not exist" -ErrorRecord $_
            return
        }

        #Stopping wsus Service if not stopped already
        if ($PSCmdlet.ShouldProcess("Stopping WSUS Service")) {
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
        }

        #Import start

        Write-PSFMessage -Message "Starting import" -Level Important
        if ($PSCmdlet.ShouldProcess("Copying WSUSContent folder")) {
            Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
            try {
                Copy-Item -Path "$Path\wsuscontent\*" -Destination $WSUSSetup.WSUSContentPath -Recurse -Force -Exclude $Exclude -ErrorAction Stop
            }
            catch {
                Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -EnableException $true###############################################
                return
            }
            Write-PSFMessage -Message "File copy complete" -Level Important
        }

        if ($PSCmdlet.ShouldProcess("Importing WSUS Metadata")) {
            Write-PSFMessage -Message "Starting import of WSUS Metadata, this will take a while." -Level Important
            <#WARNING: [14:22:31][Import-WSUSUpdates] Incomplete or invalid parameters specified. See below for correct format and
            options:   Imports update metadata (but not content files, approvals, or server settings) to this server from an export
            package file created on another WSUS server. This synchronizes this WSUS server without using a network connection.
            import <package> <log file>  <package>:          Path and filename of the package CAB file (or GZIP file with an
            .xml.gz      extension) to import     <log file>:       Path and filename of the log file to create#>
            try {
                $ImportProcess = & $WSUSSetup.WSUSUtilPath $WSUSUtilArgList #| Out-Null
                $WSUSUtilout = Select-String -Pattern "successfully imported" -InputObject $ImportProcess -ErrorAction Stop
                if ($WSUSUtilout -like "*success*") {
                    Write-PSFMessage -Message "Import was successful" -Level Important
                }
            }
            catch {
                Stop-PSFFunction -Message "Could not import metadata" -ErrorRecord $_ -EnableException $true
            }
        }

        if ($PSCmdlet.ShouldProcess("Starting WSUS Service")) {
            Write-PSFMessage -Message "Starting $($Service.DisplayName) service on $ComputerName" -Level Important

            if ($Service.Status -ne "Running") {
                try {
                    $Service.Start()
                    $Service.WaitForStatus('Running', '00:00:30')
                    Write-PSFMessage -Message "$($Service.DisplayName) service is now running on $ComputerName" -Level Important
                }
                catch {
                    Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -Continue
                }

            }
            else {
                Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -Continue
            }
        }

        if ($ImportApprovalStatus) {
            if ($PSCmdlet.ShouldProcess("Importing Approval Status")) {
                Write-PSFMessage -Message "Importing update approval status." -Level Important
                try {
                    $ExportApprovalStatus = Import-ApprovalStatus -Path $ApprovalStatusPath
                }
                catch {
                    Stop-PSFFunction
                }
            }
        }

        if ($ImportDeclinedStatus) {
            if ($PSCmdlet.ShouldProcess("Importing declined status")) {
                Write-PSFMessage -Message "Importing update declined status." -Level Important
                try {
                    $Declined = Import-DeclinedStatus -Path $DeclineStatusPath
                }
                catch {
                    Stop-PSFFunction
                }
            }
        }

        [pscustomobject]@{
            ComputerName        = $ComputerName
            Action              = "Import"
            Source              = $Path
            Destination         = $WSUSSetup.WSUSContentPath
            Result              = "Success" # can you add record numbers or any other useful info?############################################################################################################################

            #TotalSize           = (($FileInfo | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB)
            FileCount           = $PathFileCount
            ApprovedCount       = $ExportApprovalStatus.InstallCount
            NotApprovedCount    = $ExportApprovalStatus.NotApprovedCount
            DeclinedUpdateCount = $Declined.DeclinedCount
            ElapsedTIme         = [math]::Round($scriptelapsed.Elapsed.TotalSeconds, 2)
        }
    }
    End {

    }
}