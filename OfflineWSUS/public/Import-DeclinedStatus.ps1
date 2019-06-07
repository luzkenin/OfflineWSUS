function Import-DeclinedStatus {
    <#
    .SYNOPSIS
    Imports declined update status from an exported csv
    
    .DESCRIPTION
    Imports declined update status from an exported csv
    
    .PARAMETER Path
    Path to csv
    
    .EXAMPLE
    An example
    
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
            $DeclinedStatus = Import-CSV -Path $Path

            foreach ($Update in $DeclinedStatus) {
                $UpdateInfo = Get-PSWSUSUpdate -Update $Update.UpdateKB

                try {
                    Deny-PSWSUSUpdate -Update $UpdateInfo
                }
                catch {
                    Stop-PSFFunction -Message "Could not import declined status for $($("KB"+$Update.UpdateKB))" -Continue -ErrorRecord $_
                }
            }
            [PSCustomObject]@{
                DeclinedCount = $DeclinedStatus.count
            }
        }
    }

    end {
    }
}