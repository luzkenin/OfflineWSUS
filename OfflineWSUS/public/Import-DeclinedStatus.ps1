function Import-DeclinedStatus {
    [CmdletBinding()]
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
    }
    
    end {
    }
}