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
        [string]$Path,
        #path of wsuscontent
        [Parameter(Mandatory)]
        [string]$WSUSContent
    )

    begin
    {        
        $service = Get-Service -ComputerName $ComputerName -name WsusService -ErrorAction SilentlyContinue
        #$exportdate = get-date -uFormat %m%d%y
        $exportlog = "$Path\$(Get-ChildItem $Path | where Name -like "*log*")"
        $exportxml = "$Path\$(Get-ChildItem $Path | where Name -like "*xml*")"
        #$exportzip = "$Path\$(Get-ChildItem $Path | where Name -like "*zip*")"
        #$finallog = "$Destination\$exportlog"
        #$finalzip = "$Destination\$exportzip"
        $WSUSUtil = 'C:\Program Files\Update Services\Tools\WsusUtil.exe'
        $WSUSUtilArgList = @(
            "import",
            "$exportxml",
            "$exportlog"
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
                    Copy-Item -Path "$path\wsuscontent" -Destination $WSUSContent -Recurse -Force
                }
                catch
                {

                }
            }
            try
            {
                #Set-Location -Path 'C:\Program Files\Update Services\Tools'
                $ImportProcess = & $WSUSUtil $WSUSUtilArgList
                #Export-PSWSUSMetaData -FileName $finalzip -LogName $finallog -Verbose -ErrorAction stop
                #$outputvariable
                $WSUSUtilout = Select-String -Pattern "successfully imported" -InputObject $ImportProcess -ErrorAction Stop
                if($WSUSUtilout -like "*success*")
                {
                    Write-PSFMessage -Message "Import was successful" -Level Important
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