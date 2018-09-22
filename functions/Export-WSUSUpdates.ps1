function Export-WSUSUpdates
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
        [Parameter(Mandatory)]
        [string]$Destination,
        [Parameter(Mandatory)]
        [string]$WSUSContent
    )

    begin
    {        
        $service = Get-Service -ComputerName $ComputerName -name WsusService -ErrorAction SilentlyContinue
        $exportdate = get-date -uFormat %m%d%y
        $exportlog = "$exportdate.log"
        $exportzip = "$exportdate.xml.gz"
        $finallog = "$Destination\$exportlog"
        $finalzip = "$Destination\$exportzip"
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
        Write-PSFMessage -Message "Starting export" -Level Important
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
            }
        }
        try
        {
            Export-PSWSUSMetaData -FileName $finalzip -LogName $finallog -Verbose -ErrorAction stop
        }
        catch
        {
            Write-PSFMessage -Message "Could not export metadata" -Level Warning -ErrorRecord $_
        }
        if ($service.Status -ne "Running")
        {
            Write-PSFMessage -Message "Starting $($service.DisplayName) service on $computername" -Level Important
            $service.Start()
            $service.WaitForStatus('Running','00:00:20')
        }
        else
        {
            #nothing yet
        }
        if($WSUSContent)
        {
            Write-PSFMessage -Message "Copying WSUSContent folder" -Level Important
            try
            {
                Copy-Item -Path $WSUSContent -Destination $Destination -Recurse
            }
            catch
            {

            }
        }
    }

    end {
    }
}