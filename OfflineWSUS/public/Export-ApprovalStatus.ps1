function Export-ApprovalStatus {
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
            $ApprovalStatus = Get-PSWSUSUpdateApproval
            $ApprovalStatus | Export-Csv -Path $Destination -NoTypeInformation
        }
        catch {
            Stop-PSFFunction -Message "Failure" -EnableException $true -ErrorRecord $_
        }
    }

    end {
    }
}