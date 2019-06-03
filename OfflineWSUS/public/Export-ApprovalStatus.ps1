function Export-ApprovalStatus {
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
            $ApprovalStatus = Get-PSWSUSUpdateApproval
            $ApprovalStatus | Export-Csv -Path $Destination -NoTypeInformation
        }
        catch {
            Stop-PSFFunction -Message "Failure" -EnableException $true -ErrorRecord $_
        }
        [PSCustomObject]@{
            UpdateCount      = $ApprovalStatus.count
            InstallCount     = $ApprovalStatus | where action -eq "Install"
            NotApprovedCount = $ApprovalStatus | where action -eq "NotApproved"
        }
    }

    end {
    }
}