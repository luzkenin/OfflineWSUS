function Import-WSUSUpdates
{
    <#
    .SYNOPSIS

    .DESCRIPTION

    .PARAMETER

    .INPUTS

    .OUTPUTS

    .EXAMPLE

    .LINK

    #>
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,
        #Path where exported files are located
        [Parameter(Mandatory)]
        [string]$log,
        #Path where exported files are located
        [Parameter(Mandatory)]
        [string]$xml,
        #Path where exported files are located
        [Parameter(Mandatory)]
        [string]$WSUSSource,
        #path of target wsuscontent. this shouldn't have the wsuscontent folder in the path. should check for it.
        [Parameter(Mandatory)]
        [string]$WSUSContent
    )

    begin
    {        
        $service = Get-Service -ComputerName $ComputerName -name WsusService -ErrorAction SilentlyContinue
        $WSUSUtil = 'C:\Program Files\Update Services\Tools\WsusUtil.exe'
        $WSUSUtilArgList = @(
            "import",
            "$xml",
            "$log"
        )
    }

    process
    {
        $Connected = Get-PSWSUSServer
        if($null -eq $Connected)
        {
            Write-PSFMessage -Message "PoshWSUS not loaded" -Level Warning
            throw
        }
        #export
        Write-PSFMessage -Message "Starting import" -Level Important
        if ($service.Status -ne "Stopped")
        {
            Write-PSFMessage -Message "Stopping $($service.DisplayName) service on $computername" -Level Important
            $service.Stop()
            $service.WaitForStatus('Stopped','00:00:20')
            if ($service.Status -eq "Stopped")
            {
                Write-PSFMessage -Message "$($service.DisplayName) is now $($service.Status)" -Level Important
            }
            else
            {
                Write-PSFMessage -Message "Could not stop $($service.DisplayName)" -Level Warning
                throw
            }
        }
        if ($service.Status -eq "Stopped")
        {
            if($WSUSContent)
            {
                Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
                try
                {
                    Copy-Item -Path $WSUSSource -Destination $WSUSContent -Recurse -Force
                }
                catch
                {

                }
            }
            try
            {
                Write-PSFMessage -Message "Starting import of WSUS Metadata" -Level Important
                $ImportProcess = & $WSUSUtil $WSUSUtilArgList
                $WSUSUtilout = Select-String -Pattern "successfully imported" -InputObject $ImportProcess -ErrorAction Stop
                if($WSUSUtilout -like "*success*")
                {
                    Write-PSFMessage -Message "Import was successful" -Level Important
                }
                else
                {
                    $WSUSUtilError = $ImportProcess
                    throw $WSUSUtilError
                }
            }
            catch
            {
                Write-PSFMessage -Message "Could not import metadata" -Level Warning -ErrorRecord $_
            }
            if ($service.Status -ne "Running")
            {
                Write-PSFMessage -Message "Starting $($service.DisplayName) service on $computername" -Level Important
                $service.Start()
                $service.WaitForStatus('Running','00:00:30')
            }
            else
            {
                #nothing yet
            }
        }
    }

    end {
    }
}