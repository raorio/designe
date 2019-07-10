Param(
  [string]$mode = "import",
  [string]$outDir = $PSScriptRoot
  #[string]$outDir = Split-Path $MyInvocation.MyCommand.Path
  #[string]$outDir = $MyInvocation.MyCommand.Name
)
Write-Host $mode
Write-Host $outDir

filter ImportCSV($Path) {
  $DataArray = Import-Csv $Path
  $DataArray
}

filter ExportCSV($DataRrray, $FilePath) {
  $DataRrray | Export-Csv $FilePath -Encoding UTF8 -NoTypeInformation
}

filter GetApplicationWindow($ProcessNames) {
  foreach ($ProcessName in $ProcessNames) {
    Get-Process -Name $ProcessName | Set-Variable apps
    foreach ($app in $apps) {
      if ($app.MainWindowTitle -eq "") {
        continue
      }
      $Rect = New-Object RECT
      #Write-Host $app.MainWindowTitle; Write-Host $app.MainWindowHandle
      [Win32]::GetWindowRect($app.MainWindowHandle, [ref]$Rect) | Out-Null
      SetWindowRect ($app.MainWindowTitle) ($app.locationName) ($app.locationURL) ($app.MainWindowHandle) ($Rect)
    }
  }
}

filter TestGetApplicationWindow() {
  $ProcessNames = @("*")
  date
  GetApplicationWindow ($ProcessNames)
  date
}
#TestGetApplicationWindow

filter GetExplorerWindow($ProcessNames) {
  $app = New-Object -com "Shell.Application"
  $app.windows() | Set-Variable explorers
  foreach ($explorer in $explorers) {
    foreach ($ProcessName in $ProcessNames) {
      #$ProcessName
      if ($ProcessName -eq "") {
        $explorer
      } elseif ($ProcessName.IndexOf("*") -ne -1) {
        if ($explorer.Name -like $ProcessName) {
          $explorer
        }
      } else {
        if ($explorer.Name -eq $ProcessName) {
          $explorer
        }
      }
    }
  }
}
filter TestGetExplorerWindow() {
  $ProcessNames = @("�G�N�X�v���[���[", "Internet Explorer")
  date
  GetExplorerWindow ($ProcessNames)
  date
}
#TestGetExplorerWindow

filter GetExplorerWindowEachFilter($ProcessNames) {
  $app = New-Object -com "Shell.Application"
  foreach ($ProcessName in $ProcessNames) {
    #$ProcessName
    $explorers = $null
    if ($ProcessName -eq "") {
      $app.windows() | Set-Variable explorers
    } elseif ($ProcessName.IndexOf("*") -ne -1) {
      $app.windows() | where {($_.Name -like $ProcessName)} | Set-Variable explorers
    } else {
      $app.windows() | where {($_.Name -eq $ProcessName)} | Set-Variable explorers
    }
    $explorers
  }
}
filter TestGetExplorerWindowEachFilter() {
  $ProcessNames = @("�G�N�X�v���[���[", "Internet Explorer")
  date
  GetExplorerWindowEachFilter ($ProcessNames)
  date
}
#TestGetExplorerWindowEachFilter

filter GetExplorerWindowRect($ProcessNames, [String]$WindowName, [String]$PathName) {
  $explorers = GetExplorerWindow $ProcessNames
  #$explorers = GetExplorerWindowEachFilter $ProcessNames
  
  foreach ($explorer in $explorers) {
    $explorerFiterLN = $null
    $explorerFiterLU = $null
    
    if ($WindowName -eq "") {
      $explorer | Set-Variable explorerFiterLN
    } elseif ($WindowName.IndexOf("*") -ne -1) {
      $explorer | where {($_.locationName -like $WindowName)} | Set-Variable explorerFiterLN
    } else {
      $explorer | where {($_.locationName -eq $WindowName)} | Set-Variable explorerFiterLN
    }
    #$explorerFiterLN
    if ($explorerFiterLN -eq $null) {
      continue
    }
    
    if ($PathName -eq "") {
      $explorerFiterLN | Set-Variable explorerFiterLU
    } elseif ($PathName.IndexOf("*") -ne -1) {
      $explorerFiterLN | where {($_.locationURL -like $PathName)} | Set-Variable explorerFiterLU
    } else {
      $explorerFiterLN | where {($_.locationURL -eq $PathName)} | Set-Variable explorerFiterLU
    }
    #$explorerFiterLU
    if ($explorerFiterLU -eq $null) {
      continue
    }
    
    $explorerFiterLU | Set-Variable explorerT
    
    $WindowRect = New-Object WINDOW_RECT
    $WindowRect.Name = $explorerT.Name
    $WindowRect.locationName = $explorerT.locationName
    $WindowRect.locationURL = $explorerT.locationURL
    $WindowRect.HWND = $explorerT.HWND
    $WindowRect.X = $explorerT.Left
    $WindowRect.Y = $explorerT.Top
    $WindowRect.Width = $explorerT.Width
    $WindowRect.Height = $explorerT.Height
    
    $WindowRect
  }
}

# Explorer��Application���ގ�(X,Y�ALeft,Top���قȂ�����ARect�ύX���قȂ�)�̏����Ȃ̂ŁA�܂Ƃ߂�
filter SetExplorerWindowRect($SetWindowDataArray, $CurrentWindowArray, $IsDoneFlagCurrent, $IsDoneFlagData) {
  #Write-Host "SetExplorerWindowRect() start"
  
  # ���S��v������̂����{
  foreach ($CurrentWindow in $CurrentWindowArray) {
    #Write-Host "target app name"; Write-Host $CurrentWindow.Name
    $isActiveCurrent = IsActiveWindow ($CurrentWindow)
    if ($isActiveCurrent -eq $False) {
      #Write-Host "skip not active windows"; Write-Host $CurrentWindow.Left; Write-Host ", "; Write-Host $CurrentWindow.Top; $CurrentWindow
      continue
    }
    if ($IsDoneFlagCurrent[$CurrentWindow.HWND] -eq $True) {
      #Write-Host "skip already set data"; Write-Host $CurrentWindow.HWND
      continue
    }
    $isDetectChangeEqual = $False
    $isActiveCurrent = IsActiveWindow ($CurrentWindow)
    foreach ($SetWindowData in $SetWindowDataArray) {
      $isActiveData = IsActiveData ($SetWindowData)
      if ($isActiveData -eq $False) {
        #Write-Host "skip not active data"; Write-Host $SetWindowData.X; Write-Host ", "; Write-Host $SetWindowData.Y; $SetWindowData
        continue
      }
      if ($IsDoneFlagData[$SetWindowData.HWND] -eq $True) {
        #Write-Host "skip already set data"; Write-Host $SetWindowData.HWND
        continue
      }
      $isEqual = IsEqualExplorerWindow ($SetWindowData) ($CurrentWindow)
      if ($isEqual -eq $True) {
        $isDetectChangeEqual = $True
        #Write-Host "detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
        ChangeExplorerWindow ($SetWindowData) ($CurrentWindow)
        # �t���O���Z�b�g
        $IsDoneFlagCurrent.remove($CurrentWindow.HWND)
        $IsDoneFlagCurrent.add($CurrentWindow.HWND, $True)
        $IsDoneFlagData.remove($SetWindowData.HWND)
        $IsDoneFlagData.add($SetWindowData.HWND, $True)
        break
      } else {
        #Write-Host "don't detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
      }
    }
    if ($isDetectChangeEqual -eq $False) {
      # ��v����E�B���h�E���������Ȃ�����
      #Write-Host "not detect equal"
    }
  }
}

filter IsActiveWindow($CurrentWindow) {
  # X,Y���W�̂ǂ��炩��0�������ƍŏ������ʉ��z�f�X�N�g�b�v��Ɣ��f
  if ($CurrentWindow.Left -lt 0) {
    $False
    return
  }
  if ($CurrentWindow.Top -lt 0) {
    $False
    return
  }
  $True
  return
}

filter SetApplicationWindowRect($SetWindowDataArray, $CurrentWindowArray, $IsDoneFlagCurrent, $IsDoneFlagData) {
  #Write-Host "SetExplorerApplicationRect() start"
  
  # ���S��v������̂����{
  foreach ($CurrentWindow in $CurrentWindowArray) {
    #Write-Host "target app name"; Write-Host $CurrentWindow.Name
    $isActiveCurrent = IsActiveApplication ($CurrentWindow)
    if ($isActiveCurrent -eq $False) {
      #Write-Host "skip not active windows"; Write-Host $CurrentWindow.Left; Write-Host ", "; Write-Host $CurrentWindow.Top; $CurrentWindow
      continue
    }
    if ($IsDoneFlagCurrent[$CurrentWindow.HWND] -eq $True) {
      #Write-Host "skip already set data"; Write-Host $CurrentWindow.HWND
      continue
    }
    $isDetectChangeEqual = $False
    foreach ($SetWindowData in $SetWindowDataArray) {
      #Write-Host "target data name"; Write-Host $SetWindowData.Name
      $isActiveData = IsActiveData ($SetWindowData)
      if ($isActiveData -eq $False) {
        #Write-Host "skip not active data"; Write-Host $SetWindowData.X; Write-Host ", "; Write-Host $SetWindowData.Y; $SetWindowData
        continue
      }
      if ($IsDoneFlagData[$SetWindowData.HWND] -eq $True) {
        #Write-Host "skip already set data"; Write-Host $SetWindowData.HWND
        continue
      }
      $isEqual = IsEqualExplorerWindow ($SetWindowData) ($CurrentWindow)
      if ($isEqual -eq $True) {
        $isDetectChangeEqual = $True
        #Write-Host "detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName; Write-Host $CurrentWindow.HWND; Write-Host $SetWindowData.HWND
        ChangeApplicationWindow ($SetWindowData) ($CurrentWindow)
        # �t���O���Z�b�g
        $IsDoneFlagCurrent.remove($CurrentWindow.HWND)
        $IsDoneFlagCurrent.add($CurrentWindow.HWND, $True)
        $IsDoneFlagData.remove($SetWindowData.HWND)
        $IsDoneFlagData.add($SetWindowData.HWND, $True)
        break
      } else {
        #Write-Host "don't detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
      }
    }
    if ($isDetectChangeEqual -eq $False) {
      # ��v����E�B���h�E���������Ȃ�����
      #Write-Host "not detect equal"
    }
  }
}

filter SetNearApplicationWindowRect($SetWindowDataArray, $CurrentWindowArray, $IsDoneFlagCurrent, $IsDoneFlagData) {
  #Write-Host "SetNearApplicationWindowRect() start"
  
  # ������v������̂����{
  foreach ($CurrentWindow in $CurrentWindowArray) {
    #Write-Host "target app name"; Write-Host $CurrentWindow.Name
    $isActiveCurrent = IsActiveApplication ($CurrentWindow)
    if ($isActiveCurrent -eq $False) {
      #Write-Host "skip not active windows"; Write-Host $CurrentWindow.Left; Write-Host ", "; Write-Host $CurrentWindow.Top; $CurrentWindow
      continue
    }
    if ($IsDoneFlagCurrent[$CurrentWindow.HWND] -eq $True) {
      #Write-Host "skip already set data"; Write-Host $CurrentWindow.HWND
      continue
    }
    $isDetectChangeEqual = $False
    foreach ($SetWindowData in $SetWindowDataArray) {
      #Write-Host "target data name"; Write-Host $SetWindowData.Name
      $isActiveData = IsActiveData ($SetWindowData)
      if ($isActiveData -eq $False) {
        #Write-Host "skip not active data"; Write-Host $SetWindowData.X; Write-Host ", "; Write-Host $SetWindowData.Y; $SetWindowData
        continue
      }
      if ($IsDoneFlagData[$SetWindowData.HWND] -eq $True) {
        #Write-Host "skip already set data"; Write-Host $SetWindowData.HWND
        continue
      }
      $isEqual = IsNearEqualExplorerWindow ($SetWindowData) ($CurrentWindow)
      if ($isEqual -eq $True) {
        $isDetectChangeEqual = $True
        #Write-Host "detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName; Write-Host $CurrentWindow.HWND; Write-Host $SetWindowData.HWND
        ChangeApplicationWindow ($SetWindowData) ($CurrentWindow)
        # �t���O���Z�b�g
        $IsDoneFlagCurrent.remove($CurrentWindow.HWND)
        $IsDoneFlagCurrent.add($CurrentWindow.HWND, $True)
        $IsDoneFlagData.remove($SetWindowData.HWND)
        $IsDoneFlagData.add($SetWindowData.HWND, $True)
        break
      } else {
        #Write-Host "don't detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
      }
    }
    if ($isDetectChangeEqual -eq $False) {
      # ��v����E�B���h�E���������Ȃ�����
      #Write-Host "not detect equal"
    }
  }
}

filter IsActiveApplication($CurrentWindow) {
  # X,Y���W�̂ǂ��炩��0�������ƍŏ������ʉ��z�f�X�N�g�b�v��Ɣ��f
  if ($CurrentWindow.X -lt 0) {
    $False
    return
  }
  if ($CurrentWindow.Y -lt 0) {
    $False
    return
  }
  $True
  return
}

filter IsActiveData($SetWindowData) {
  # X,Y���W�̂ǂ��炩��0�������ƍŏ������ʉ��z�f�X�N�g�b�v��Ɣ��f
  if ($SetWindowData.X -lt 0) {
    $False
    return
  }
  if ($SetWindowData.Y -lt 0) {
    $False
    return
  }
  $True
  return
}

# Explorer�����łȂ��AApplication���{API���g�p
filter IsEqualExplorerWindow($SetWindowData, $CurrentWindow) {
  #Write-Host "IsEqualExplorerWindow() start"; Write-Host "SetWindowData"; Write-Host $SetWindowData; Write-Host "CurrentWindow"; Write-Host $CurrentWindow
  $isEqual = $False
  $isEqualName = $False
  $isEqualLocationName = $False
  $isEqualLocationURL = $False
  if ($CurrentWindow.Name -eq $SetWindowData.Name) {
    $isEqualName = $True
  }
  if ($CurrentWindow.locationName -eq $SetWindowData.locationName) {
    $isEqualLocationName = $True
  }
  if ($CurrentWindow.locationURL -eq $SetWindowData.locationURL) {
    $isEqualLocationURL = $True
  }
  if ($isEqualName -eq $True) {
    if ($isEqualLocationName -eq $True) {
      if ($isEqualLocationURL -eq $True) {
        #Write-Host "equal window"; Write-Host $isEqualName; Write-Host $isEqualLocationName; Write-Host $isEqualLocationURL
        $isEqual = $True
        return $isEqual
      }
    }
  }
  #Write-Host "not equal window"
  return $isEqual
}

filter IsNearEqualExplorerWindow($SetWindowData, $CurrentWindow) {
  Write-Host "IsNearEqualExplorerWindow() start"; Write-Host "SetWindowData"; Write-Host $SetWindowData; Write-Host "CurrentWindow"; Write-Host $CurrentWindow
  $isEqual = $False
  $isEqualName = $False
  #$isEqualLocationName = $False
  #$isEqualLocationURL = $False
  # �A�v���P�[�V����������v����΁A��v�Ɣ��f����
  $currentWindowAppName = GetApplicationName $CurrentWindow.Name
  $setWindowDataAppName = GetApplicationName $SetWindowData.Name
  #Write-Host "currentWindowAppName: "; Write-Host $currentWindowAppName; Write-Host "setWindowDataAppName: "; Write-Host $setWindowDataAppName
  if ($currentWindowAppName -eq $setWindowDataAppName) {
    #Write-Host "equal application name, therefore near equal."
    $isEqualName = $True
  }
  #if ($CurrentWindow.locationName -eq $SetWindowData.locationName) {
  #  $isEqualLocationName = $True
  #}
  #if ($CurrentWindow.locationURL -eq $SetWindowData.locationURL) {
  #  $isEqualLocationURL = $True
  #}
  #if ($isEqualName -eq $True) {
  #  if ($isEqualLocationName -eq $True) {
  #    if ($isEqualLocationURL -eq $True) {
  #      #Write-Host "equal window"; Write-Host $isEqualName; Write-Host $isEqualLocationName; Write-Host $isEqualLocationURL
  #      $isEqual = $True
  #      return $isEqual
  #    }
  #  }
  #}
  if ($isEqualName -eq $True) {
    $isEqual = $True
    return $isEqual
  }
  #Write-Host "not equal window"
  return $isEqual
}

filter GetApplicationName($name) {
  # Name��"-"�ŕ������A�㔼���A�v���P�[�V�������Ƃ���
  $nameArray = $name -split " - "
  #$nameArray = $name.Split(" - ") # NG���܂������ł��Ă��Ȃ�
  #Write-Host $nameArray[0]
  #Write-Host $nameArray[$nameArray.Length - 1]
  return $nameArray[$nameArray.Length - 1]
}

filter ChangeExplorerWindow($SetWindowData, $CurrentWindow) {
  #Write-Host "ChangeExplorerWindow() start"; Write-Host "SetWindowData"; Write-Host $SetWindowData; Write-Host "CurrentWindow"; Write-Host $CurrentWindow
  if ($CurrentWindow.Name -eq "Internet Explorer") {
    #Write-Host "change ie size"
    # �T�C�Y��3/2�{�ɂȂ苶���̂ŁA2/3�{����B
    [Win32]::MoveWindow($CurrentWindow.HWND, $SetWindowData.X / 3 * 2, $SetWindowData.Y / 3 * 2, $SetWindowData.Width / 3 * 2, $SetWindowData.Height / 3 * 2, $true)
    #[Win32]::MoveWindow($CurrentWindow.HWND, $SetWindowData.X, $SetWindowData.Y, $SetWindowData.Width, $SetWindowData.Height, $true)
  #} elseif ($CurrentWindow.Name -eq "�G�N�X�v���[���[") {
  } else {
    #Write-Host "change explorer size"
    $CurrentWindow.Top = $SetWindowData.Y
    $CurrentWindow.Left = $SetWindowData.X
    $CurrentWindow.Width = $SetWindowData.Width
    $CurrentWindow.Height = $SetWindowData.Height
  #} else {
  #  Write-Host "change application size"
  #  [Win32]::MoveWindow($CurrentWindow.HWND, $SetWindowData.X, $SetWindowData.Y, $SetWindowData.Width, $SetWindowData.Height, $true)
  }
}

filter ChangeApplicationWindow($SetWindowData, $CurrentWindow) {
  #Write-Host "ChangeExplorerApplication() start"; Write-Host "SetWindowData"; Write-Host $SetWindowData; Write-Host "CurrentWindow"; Write-Host $CurrentWindow
  [Win32]::MoveWindow([int]$CurrentWindow.HWND, $SetWindowData.X, $SetWindowData.Y, $SetWindowData.Width, $SetWindowData.Height, $true)
}

filter SetWindowRect($name, $locationName, $locationURL, $HWND, $rc) {
  $WindowRect = New-Object WINDOW_RECT
  
  $WindowRect.Name = $name
  $WindowRect.locationName = $locationName
  $WindowRect.locationURL = $locationURL
  $WindowRect.HWND = $HWND
  $WindowRect.X = $rc.Left
  $WindowRect.Y = $rc.Top
  $WindowRect.Width = $rc.Right - $rc.Left
  $WindowRect.Height = $rc.Bottom - $rc.Top
  
  $WindowRect
}

######
# C# #
######

Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  
  public class Win32 {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveWindow(IntPtr hwhd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hwhd, out RECT lpRect);
  }
  
  public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }
  
  public struct WINDOW_RECT {
    public string Name;
    public string locationName;
    public string locationURL;
    public string HWND;
    public int X;
    public int Y;
    public int Width;
    public int Height;
  }
"@

########
# test #
########

$FilePath = "$outDir" + ".\explorer_windows.csv"

if ($mode -eq "export") {
  $Export = $True
  $Inport = $False
} else {
  $Export = $False
  $Inport = $True
}

# IE�́A�^�u����������ꍇ�A�T�C�Y�ύX�ł��Ȃ��BMoveWindow�Ŏ��{����B
$ProcessNames = @("�G�N�X�v���[���[", "Internet Explorer")
#$ProcessNames = @("�G�N�X�v���[���[")
Write-Host "ProcessNames: "; Write-Host $ProcessNames
foreach($ProcessName in $ProcessNames) {
  Write-Host "ProcessName: "; Write-Host $ProcessName
}

if ($Export -eq $True) {
  $rect = $null
  $WindowName = ""
  #$WindowName = "*"
  #$WindowName = "PS"
  #$WindowName = "psChangeWH"
  #Write-Host "WindowName: "; Write-Host $WindowName
  $PathName = ""
  #Write-Host "PathName: "; Write-Host $PathName
  
  GetExplorerWindowRect ($ProcessNames) ($WindowName) ($PathName) | Set-Variable GetWindowsDataArray
  #Write-Host "GetWindowsDataArray: "; Write-Host $GetWindowsDataArray; $GetWindowsDataArray
  
  $appProcessName = @("*")
  GetApplicationWindow ($appProcessName) | Set-Variable GetApplicationDataArray
  #Write-Host "GetApplicationDataArray: "; Write-Host $GetApplicationDataArray; $GetApplicationDataArray
  
  if ($GetWindowsDataArray.GetType().Name -ne "Object[]") {
    if ($GetApplicationDataArray.GetType().Name -ne "Object[]") {
      $GetWindowsApplicationDataArray = @($GetWindowsDataArray, $GetApplicationDataArray)
    } else {
      $GetWindowsApplicationDataArray = @($GetWindowsDataArray) + $GetApplicationDataArray
    }
  } else {
    if ($GetApplicationDataArray.GetType().Name -ne "Object[]") {
      $GetWindowsApplicationDataArray = $GetWindowsDataArray + @($GetApplicationDataArray)
    } else {
      $GetWindowsApplicationDataArray = $GetWindowsDataArray + $GetApplicationDataArray
    }
  }
  #Write-Host "GetWindowsApplicationDataArray: "; Write-Host $GetWindowsApplicationDataArray; $GetWindowsApplicationDataArray
  
  ExportCSV ($GetWindowsApplicationDataArray) $FilePath
}

if ($Inport -eq $True) {
  ImportCSV ($FilePath) | Set-Variable LoadWindowsApplicationDataArray
  #Write-Host "LoadWindowsApplicationDataArray: "; Write-Host $LoadWindowsApplicationDataArray; $LoadWindowsApplicationDataArray
  
  $IsDoneFlagData = @{}
  foreach ($SetWindowData in $LoadWindowsApplicationDataArray) {
    $IsDoneFlagData.add($LoadWindowsApplicationDataArray.HWND, $False)
  }
  
  $CurrentWindows = GetExplorerWindowEachFilter ($ProcessNames)
  Write-Host "CurrentWindows"; Write-Host $CurrentWindows; $CurrentWindows
  
  $IsDoneFlagCurrent = @{}
  foreach ($CurrentWindow in $CurrentWindows) {
    if ($CurrentWindow.HWND -eq $Null) {
      #Write-Host "$CurrentWindow.HWND is Null, skip"
      continue
    }
    #Write-Host "target HWND"; Write-Host $CurrentWindow.HWND
    if ($IsDoneFlagCurrent.containsKey($CurrentWindow.HWND) -eq $True) {
      #Write-Host "duplicate HWND"; Write-Host $CurrentWindow.HWND
      $IsDoneFlagCurrent.remove($CurrentWindow.HWND)
    }
    $IsDoneFlagCurrent.add($CurrentWindow.HWND, $False)
  }
  
  SetExplorerWindowRect ($LoadWindowsApplicationDataArray) ($CurrentWindows) ($IsDoneFlagCurrent) ($IsDoneFlagData)
  
  $appProcessName = @("*")
  GetApplicationWindow ($appProcessName) | Set-Variable GetApplicationDataArray
  #Write-Host "GetApplicationDataArray: "; Write-Host $GetApplicationDataArray; $GetApplicationDataArray
  
  $IsDoneFlagCurrent = @{}
  foreach ($CurrentApplication in $GetApplicationDataArray) {
    if ($CurrentApplication.HWND -eq $Null) {
      #Write-Host "$CurrentApplication.HWND is Null, skip"
      continue
    }
    #Write-Host "target HWND"; Write-Host $CurrentApplication.HWND
    if ($IsDoneFlagCurrent.containsKey($CurrentApplication.HWND) -eq $True) {
      #Write-Host "duplicate HWND"; Write-Host $CurrentApplication.HWND
      $IsDoneFlagCurrent.remove($CurrentApplication.HWND)
    }
    $IsDoneFlagCurrent.add($CurrentApplication.HWND, $False)
  }
  
  SetApplicationWindowRect ($LoadWindowsApplicationDataArray) ($GetApplicationDataArray) ($IsDoneFlagCurrent) ($IsDoneFlagData)
  SetNearApplicationWindowRect ($LoadWindowsApplicationDataArray) ($GetApplicationDataArray) ($IsDoneFlagCurrent) ($IsDoneFlagData)
}
