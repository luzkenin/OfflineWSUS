function Test-LocalResource {
    [CmdletBinding()]
    param (
        # Parameter help description
        [OutputType([Bool])]
        [Parameter(Mandatory)]
        [string]
        $ComputerName
    )

    begin {
    }

    process {
        if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -like "localhost") {
            $true
        }
        else {
            $false
        }
    }

    end {
    }
}