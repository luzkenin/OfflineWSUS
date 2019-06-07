function Export-WSUSUpdatePackage {
    <#
    .SYNOPSIS
        Exports WSUS update metadata and binaries from a server.

    .DESCRIPTION
        Exports update metadata and binaries from a server to a folder.
        This will allow you to synchronize the destination WSUS server without using a network connection.

        See https://docs.microsoft.com/de-de/security-updates/windowsupdateServices/18127395 for more information.

    .PARAMETER ComputerName
        The target computer that will perform the import. Defaults to localhost.

    .PARAMETER Destination
        Location of where the files will go.

    .PARAMETER ExportApprovalStatus
        Switch to export approval status
    .PARAMETER ExportDeclinedStatus
        Switch to export declined status

    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,
        [Parameter(Mandatory)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$Destination,
        # Parameter help description
        [Parameter()]
        [switch]
        $ExportApprovalStatus,
        # Parameter help description
        [Parameter()]
        [switch]
        $ExportDeclinedStatus
    )

    begin {
        $WSUSSetup = Get-WSUSSetupInfo -ComputerName $ComputerName
        $Service = Get-Service -ComputerName $ComputerName -name "WsusService" -ErrorAction SilentlyContinue
        [string]$ExportDate = get-date -uFormat %m%d%y
        $ExportLog = "$ExportDate.log"
        $ExportZip = "$ExportDate.xml.gz"
        $FinalLog = "$Destination\$ExportLog"
        $FinalZip = "$Destination\$ExportZip"
        #$Exclude = Get-ChildItem -Path $Destination -recurse
        [string]$FinalApprovalCSV = $Destination + "\" + ($ExportDate + "ApprovalStatus.csv")
        [string]$FinalDeclinedCSV = $Destination + "\" + ($ExportDate + "DeclinedStatus.csv")
        [array]$FileInfo = Get-ChildItem -Path $WSUSSetup.WSUSContentPath -Recurse

        try {
            Get-PSWSUSServer | Out-Null
        }
        catch {
            Stop-PSFFunction -Message "Use Connect-PSWSUSServer to establish connection with your Windows Update Server" -ErrorRecord $_
        }
    }

    process {

        #export
        Write-PSFMessage -Message "Starting export" -Level Important
        if ($Service.Status -ne "Stopped") {
            Write-PSFMessage -Message "Stopping $($Service.DisplayName) Service on $computername" -Level Important
            $Service.Stop()
            $Service.WaitForStatus('Stopped', '00:00:20')
            if ($Service.Status -eq "Stopped") {
                Write-PSFMessage -Message "$($Service.DisplayName) is now $($Service.Status)" -Level Important
            }
            else {
                Stop-PSFFunction -Message "Could not stop $($Service.DisplayName)" -ErrorRecord $_
                $Result = "Could not stop $($Service.DisplayName)"
            }
        }
        Write-PSFMessage -Message "Starting Metadata export" -Level Important
        try {
            $CatchExport = Export-PSWSUSMetaData -FileName $FinalZip -LogName $FinalLog -ErrorAction stop
            $result = "Success"
        }
        catch {
            Stop-PSFFunction -Message "Could not export metadata" -ErrorRecord $_
            $Result = "Export failed"
        }

        if ($WSUSSetup.WSUSContentPath | Test-Path) {
            Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
            try {
                Copy-Item -Path $WSUSSetup.WSUSContentPath -Destination $Destination -Recurse -Force -ErrorAction Stop
                $Result = "Success"
            }
            catch {
                Stop-PSFFunction -Message "Could not copy all files" -ErrorRecord $_
                $Result = "Could not copy all files"
                return
            }
        }

        if ($Service.Status -ne "Running") {
            Write-PSFMessage -Message "Starting $($Service.DisplayName) Service on $computername" -Level Important
            $Service.Start()
            $Service.WaitForStatus('Running', '00:00:20')
        }

        if ($ExportApprovalStatus.IsPresent) {
            Write-PSFMessage -Message "Exporting approval statuses" -Level Important
            try {
                Export-ApprovalStatus -Destination $FinalApprovalCSV
                $result = "Success"
            }
            catch {
                Stop-PSFFunction
            }
        }
        if ($ExportDeclinedStatus.IsPresent) {
            Write-PSFMessage -Message "Exporting declined statuses" -Level Important
            try {
                $Declined = Export-DeclinedStatus -Destination $FinalDeclinedCSV
                $Result = "Success"
            }
            catch {
                Stop-PSFFunction
            }
        }


        [pscustomobject]@{
            ComputerName        = $ComputerName
            Action              = "Export"
            Source              = $WSUSSetup.WSUSContentPath
            Destination         = $Destination
            TotalSize           = (($FileInfo | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB)
            FileCount           = $FileInfo.count
            ApprovedCount       = $ExportApprovalStatus.InstallCount
            NotApprovedCount    = $ExportApprovalStatus.NotApprovedCount
            DeclinedUpdateCount = $Declined.DeclinedCount
            Result              = $Result # can you add record numbers or any other useful info?
            #ElapsedTime = $Elapsed
        }
    }
    end {
        $CatchExport | Out-Null
    }
}