function Import-WSUSUpdates {
    <#
    .SYNOPSIS
    Imports WSUS update metadata to a server.
    
    .DESCRIPTION
    Imports update metadata to a server from an export package file created on another WSUS server. 
    This synchronizes the destination WSUS server without using a network connection.
    
    See https://docs.microsoft.com/de-de/security-updates/windowsupdateservices/18127395 for more information.
    
    .PARAMETER ComputerName
        The target computer that will perform the import. Defaults to localhost.
    
    .PARAMETER LogFile
         The path and file name of the log file.
    
    .PARAMETER Xml
        Path to the import approval metadata Xml.

    .PARAMETER ContentSource
        Path of source wsuscontent (if they pass the wsuscontent folder in the path, auto strip it?)

    .PARAMETER ContentDestination
        Path of destination wsuscontent. Why is this beneficial? I don't use the product, 
        have no idea and would like to know. So would be good to include in help.
    
    .PARAMETER WsusUtilPath
        The path to wsusutil.exe. Defaults to "C:\Program Files\Update Services\Tools\WsusUtil.exe"
    
    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .INPUTS

    .OUTPUTS

    .EXAMPLE

    .LINK

    #>
    [CmdletBinding()]
    param (
        [string]$ComputerName = $env:COMPUTERNAME,
        [Parameter(Mandatory)]
        [string]$LogFile,
        [Parameter(Mandatory)]
        [string]$Xml,
        [Parameter(Mandatory)]
        [string]$ContentSource,
        [Parameter(Mandatory)]
        [string]$ContentDestination,
        [string]$WsusUtilPath = "C:\Program Files\Update Services\Tools\WsusUtil.exe",
        [switch]$EnableException
    )
    
    begin {
        $service = Get-Service -ComputerName $ComputerName -name WsusService -ErrorAction SilentlyContinue
        $WSUSUtilArgList = @(
            "import",
            "$Xml",
            "$LogFile"
        )
    }
    
    process {
        if (-not (Get-PSWSUSServer -WarningAction SilentlyContinue)) {
            # Module is imported automatically because of psd1. 
            Stop-PSFFunction -Message "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            return
        }
        
        if (-not (Test-Path $WsusUtilPath)) {
            Stop-PSFFunction -Message "$WsusUtilPath does not exist"
            return
        }
        
        Write-PSFMessage -Message "Starting import" -Level Important
        
        if ($service.Status -ne "Stopped") {
            Write-PSFMessage -Message "Stopping $($service.DisplayName) service on $computername" -Level Important
            $service.Stop()
            $service.WaitForStatus('Stopped', '00:00:20')
            if ($service.Status -eq "Stopped") {
                Write-PSFMessage -Message "$($service.DisplayName) is now $($service.Status)" -Level Important
            }
            else {
                Stop-PSFFunction -Message "Could not stop $($service.DisplayName)" -Continue
            }
        }
        if ($service.Status -eq "Stopped") {
            if ($ContentDestination) {
                Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
                try {
                    Copy-Item -Path $ContentSource -Destination $ContentDestination -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -Continue
                }
            }
            try {
                Write-PSFMessage -Message "Starting import of WSUS Metadata, this will take a while." -Level Important
                $ImportProcess = & $WsusUtilPath $WSUSUtilArgList
                $WSUSUtilout = Select-String -Pattern "successfully imported" -InputObject $ImportProcess -ErrorAction Stop
                if ($WSUSUtilout -like "*success*") {
                    Write-PSFMessage -Message "Import was successful" -Level Important
                }
                else {
                    Stop-PSFFunction -Message "$ImportProcess" -Continue
                }
            }
            catch {
                Write-PSFMessage -Message "Could not import metadata" -Level Warning -ErrorRecord $_
            }
            if ($service.Status -ne "Running") {
                Write-PSFMessage -Message "Starting $($service.DisplayName) service on $computername" -Level Important
                $service.Start()
                $service.WaitForStatus('Running', '00:00:60')
            }
            else {
                Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -Continue
            }
        }
        [pscsutomobject]@{
            ComputerName = $ComputerName
            Action       = "Import"
            Result       = "Success" # can you add record numbers or any other useful info?
        }
    }
}