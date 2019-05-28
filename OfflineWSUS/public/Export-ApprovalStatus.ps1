function Export-ApprovalStatus {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [System.IO.FileInfo]
        $Path
    )

    begin {
    }

    process {
        try {
            Get-PSWSUSUpdateApproval | Export-Csv -Path "$Path\ApprovalStatus.csv" -NoTypeInformation
        }
        catch {
            Stop-PSFFunction -Message "Failure" -EnableException $true -ErrorRecord $_
        }
    }

    end {
    }
}