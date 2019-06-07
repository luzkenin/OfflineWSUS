function Import-ApprovalStatus {
    <#
    .SYNOPSIS
    Imports approval status

    .DESCRIPTION
    Imports approval status from csv

    .PARAMETER Path
    Path to csv

    .EXAMPLE
    Import-ApprovalStatus -Path C:\temp\csv.csv

    .NOTES
    General notes
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [ValidateScript( { Test-Path -Path $_ })]
        [System.IO.FileInfo]
        $Path
    )

    begin {
    }

    process {
        if ($PSCmdlet.ShouldProcess($Path, "Importing update approval status.")) {
            $ApprovalStatus = Import-CSV -Path $Path

            foreach ($Update in $ApprovalStatus) {
                $UpdateInfo = Get-PSWSUSUpdate -Update $Update.UpdateKB
                $Groups = $Update | % { Get-PSWSUSGroup -Name $_.TargetGroup }
                $Action = $Update | select -ExpandProperty "Action"
                try {
                    Approve-PSWSUSUpdate -Update $UpdateInfo -Action $Action -Group $Groups
                }
                catch {
                    Stop-PSFFunction -Message "Could not import approval status for $($("KB"+$Update.UpdateKB))" -Continue -ErrorRecord $_
                }
            }
            [PSCustomObject]@{
                UpdateCount      = $ApprovalStatus.count
                InstallCount     = $ApprovalStatus | where action -eq "Install"
                NotApprovedCount = $ApprovalStatus | where action -eq "NotApproved"
            }
        }
    }

    end {
    }
}