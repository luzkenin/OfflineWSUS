function Export-WSUSUpdates {
    <#
    .SYNOPSIS
    Exports WSUS update metadata and binaries from a server.

    .DESCRIPTION
    Exports update metadata and binaries from a server to a folder. 
    This will allow you to synchronize the destination WSUS server without using a network connection.
    
    See https://docs.microsoft.com/de-de/security-updates/windowsupdateservices/18127395 for more information.

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
        [string]$WSUSContent,
        [Parameter(Mandatory)]
        [string]$Destination
    )

    begin {
    }

    process {
        $service = Get-Service -ComputerName $ComputerName -name WsusService -ErrorAction SilentlyContinue
        $exportdate = get-date -uFormat %m%d%y
        $exportlog = "$exportdate.log"
        $exportzip = "$exportdate.xml.gz"
        $finallog = "$Destination\$exportlog"
        $finalzip = "$Destination\$exportzip"
        $FileInfo = Get-ChildItem -Path $WSUSContent -Recurse

        if (-not (Get-PSWSUSServer -WarningAction SilentlyContinue)) {
            # Module is imported automatically because of psd1. 
            Stop-PSFFunction -Message "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            return
        }
        #export
        Write-PSFMessage -Message "Starting export" -Level Important
        if ($service.Status -ne "Stopped") {
            Write-PSFMessage -Message "Stopping $($service.DisplayName) service on $computername" -Level Important
            $service.Stop()
            $service.WaitForStatus('Stopped','00:00:20')
            if ($service.Status -eq "Stopped") {
                Write-PSFMessage -Message "$($service.DisplayName) is now $($service.Status)" -Level Important
            }
            else {
                Stop-PSFFunction -Message "Could not stop $($service.DisplayName)" -ErrorRecord $_ -Continue
            }
        }
        try {
            Export-PSWSUSMetaData -FileName $finalzip -LogName $finallog -ErrorAction stop
        }
        catch {
            Stop-PSFFunction -Message "Could not export metadata" -ErrorRecord $_ -Continue
        }
        if ($service.Status -ne "Running") {
            Write-PSFMessage -Message "Starting $($service.DisplayName) service on $computername" -Level Important
            $service.Start()
            $service.WaitForStatus('Running','00:00:20')
        }

        if($WSUSContent) {
            Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
            try {
                Copy-Item -Path $WSUSContent -Destination $Destination -Recurse -ErrorAction Stop
            }
            catch {
                Stop-PSFFunction -Message "Could not copy all files" -ErrorRecord $_
                return
            }
        }
        [pscustomobject]@{
            ComputerName = $ComputerName
            Action       = "Export"
            Result       = "Success" # can you add record numbers or any other useful info?
            Size         = (($FileInfo | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB)
            Count        = $FileInfo.count
        }
    }
}