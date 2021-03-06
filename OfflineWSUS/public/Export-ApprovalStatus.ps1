function Export-ApprovalStatus {
    <#
    .SYNOPSIS
    Exports update approval status

    .DESCRIPTION
    Exports update approval status using PoshWSUS command 'Get-PSWSUSUpdateApproval' and saves it as csv.

    .PARAMETER Destination
    Destination of output csv

    .EXAMPLE
    Export-ApprovalStatus -Destination C;\temp\appstatus.csv

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
            Destination      = $Destination
        }
    }

    end {
    }
}