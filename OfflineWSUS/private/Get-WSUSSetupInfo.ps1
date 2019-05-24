function Get-WSUSSetupInfo {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    begin {
    }

    process {
        if ($ComputerName -eq $env:COMPUTERNAME) {
            $WSUSInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup"
        }
        else {
            $WSUSInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup" }
        }

        [PSCustomObject]@{
            ComputerName    = $ComputerName
            WSUSContentPath = ($WSUSInfo.ContentDir + "\wsuscontent")
            WSUSUtilPath    = ($WSUSInfo.TargetDir + "Tools\WsusUtil.exe")
        }
    }

    end {
    }
}