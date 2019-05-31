function Export-DeclinedStatus {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory)]
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
        }
    }

    end {
    }
}