function Import-ApprovalStatus {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [System.IO.FileInfo]
        $Path
    )

    begin {
    }

    process {
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
    }

    end {
    }
}