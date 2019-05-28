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
            $ContentDir = ($WSUSInfo.ContentDir + "\wsuscontent")
            $WSUSUtilPath = ($WSUSInfo.TargetDir + "Tools\WsusUtil.exe")
            $WSUSContentPathExists = Test-Path -Path $ContentDir
            $WSUSUtilPathExists = Test-Path -Path $WSUSUtilPath
        }
        else {
            $WSUSInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup" }
            $ContentDir = ($WSUSInfo.ContentDir + "\wsuscontent")
            $WSUSUtilPath = ($WSUSInfo.TargetDir + "Tools\WsusUtil.exe")
            $WSUSContentPathExists = Invoke-Command -ComputerName $ComputerName -ScriptBlock { Test-Path -Path $Using:ContentDir }
            $WSUSUtilPathExists = Invoke-Command -ComputerName $ComputerName -ScriptBlock { Test-Path -Path $Using:WSUSUtilPath }
        }

        [PSCustomObject]@{
            ComputerName          = $ComputerName
            WSUSContentPath       = $ContentDir
            WSUSContentPathExists = $WSUSContentPathExists
            WSUSUtilPath          = $WSUSUtilPath
            WSUSUtilPathExists    = $WSUSUtilPathExists
        }
    }

    end {
    }
}