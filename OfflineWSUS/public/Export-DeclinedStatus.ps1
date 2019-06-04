function Export-DeclinedStatus {
    <#
    .SYNOPSIS
    Exports update declined status

    .DESCRIPTION
    Exports update declined status using PoshWSUS command 'Get-PSWSUSUpdate' and saves it as csv.

    .PARAMETER Destination
    Destination of output csv

    .EXAMPLE
    Export-DeclinedStatus -Destination C:\temp\appstatus.csv

    #>
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [validatepattern("\.[csv]+$")]
        [string]
        $Destination
    )

    begin {
    }

    process {
        try {
            $Declined = Get-PSWSUSUpdate | where IsDeclined -eq $true
            $Declined | Export-Csv -Path $Destination -NoTypeInformation
        }
        catch {
            Stop-PSFFunction -Message "Failure" -EnableException $true -ErrorRecord $_
        }
        [PSCustomObject]@{
            DeclinedCount = $Declined.count
            Destination   = $Destination
        }
    }

    end {
    }
}