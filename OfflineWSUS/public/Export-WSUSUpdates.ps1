function Export-WSUSUpdates {
    <#
    .SYNOPSIS
    Exports WSUS update metadata and binaries from a server.

    .DESCRIPTION
    Exports update metadata and binaries from a server to a folder. 
    This will allow you to synchronize the destination WSUS server without using a network connection.
    
    See https://docs.microsoft.com/de-de/security-updates/windowsupdateServices/18127395 for more information.

    .PARAMETER ComputerName
        The target computer that will perform the import. Defaults to localhost.

    .PARAMETER WSUSContent
    Location of the WSUSContent folder.

    .PARAMETER Destination
    Location of where the files will go.

    .INPUTS

    .OUTPUTS

    .EXAMPLE

    .LINK

    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,
        [Parameter(Mandatory)]
        [system.IO.fileinfo]$Destination,
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
    }

    process {
        $Service = Get-Service -ComputerName $ComputerName -name "WsusService" -ErrorAction SilentlyContinue
        $ExportDate = get-date -uFormat %m%d%y
        $ExportLog = "$ExportDate.log"
        $ExportZip = "$ExportDate.xml.gz"
        $FinalLog = "$Destination\$ExportLog"
        $FinalZip = "$Destination\$ExportZip"
        $FileInfo = Get-ChildItem -Path $WSUSContent -Recurse

        if (-not (Get-PSWSUSServer -WarningAction SilentlyContinue)) {
            # Module is imported automatically because of psd1. 
            Stop-PSFFunction -Message "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            return
        }
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
        try {
            Export-PSWSUSMetaData -FileName $FinalZip -LogName $FinalLog -ErrorAction stop
        }
        catch {
            Stop-PSFFunction -Message "Could not export metadata" -ErrorRecord $_
            $Result = "Export failed"
        }
        if ($Service.Status -ne "Running") {
            Write-PSFMessage -Message "Starting $($Service.DisplayName) Service on $computername" -Level Important
            $Service.Start()
            $Service.WaitForStatus('Running', '00:00:20')
        }

        if ($WSUSContent) {
            Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
            try {
                Copy-Item -Path $WSUSContent -Destination $Destination -Recurse -ErrorAction Stop
            }
            catch {
                Stop-PSFFunction -Message "Could not copy all files" -ErrorRecord $_
                $Result = "Could not copy all files"
                return
            }
        }
        if ($ExportApprovalStatus) {
            #Get-PSWSUSUpdateApproval | Export-Csv -Path $Destination\ApprovalStatus.csv -NoTypeInformation
        }
        [pscustomobject]@{
            ComputerName = $ComputerName
            Action       = "Export"
            Result       = $Result # can you add record numbers or any other useful info?
            TotalSize    = (($FileInfo | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB) + "GB"
            FileCount    = $FileInfo.count
            Destination  = $Destination
            Source       = $WSUSContent

        }
    }
}