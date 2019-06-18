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
  $ProcessNames = @("エクスプローラー", "Internet Explorer")
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
  $ProcessNames = @("エクスプローラー", "Internet Explorer")
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

# ExplorerとApplicationが類似(X,Y、Left,Topが異なったり、Rect変更が異なる)の処理なので、まとめる
filter SetExplorerWindowRect($SetWindowDataArray, $CurrentWindowArray) {
  #Write-Host "SetExplorerWindowRect() start"
  foreach ($CurrentWindow in $CurrentWindowArray) {
    $isDetectChangeEqual = $False
    $isActiveCurrent = IsActiveWindow ($CurrentWindow)
    if ($isActiveCurrent -eq $False) {
      #Write-Host "skip not active windows"; Write-Host $CurrentWindow.Left; Write-Host ", "; Write-Host $CurrentWindow.Top; $CurrentWindow
      continue
    }
    foreach ($SetWindowData in $SetWindowDataArray) {
      $isActiveData = IsActiveData ($SetWindowData)
      if ($isActiveData -eq $False) {
        #Write-Host "skip not active data"; Write-Host $SetWindowData.X; Write-Host ", "; Write-Host $SetWindowData.Y; $SetWindowData
        continue
      }
      $isEqual = IsEqualExplorerWindow ($SetWindowData) ($CurrentWindow)
      if ($isEqual -eq $True) {
        $isDetectChangeEqual = $True
        #Write-Host "detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
        ChangeExplorerWindow ($SetWindowData) ($CurrentWindow)
      } else {
        #Write-Host "don't detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
      }
    }
    if ($isDetectChangeEqual -eq $False) {
      # 一致するウィンドウが見つけられなかった
      # あいまい検索を実行
    }
  }
}

filter IsActiveWindow($CurrentWindow) {
  # X,Y座標のどちらかが0未満だと最小化か別仮想デスクトップ上と判断
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

filter SetApplicationWindowRect($SetWindowDataArray, $CurrentWindowArray) {
  #Write-Host "SetExplorerApplicationRect() start"
  foreach ($CurrentWindow in $CurrentWindowArray) {
    #Write-Host "target app name"; Write-Host $CurrentWindow.Name
    $isDetectChangeEqual = $False
    $isActiveCurrent = IsActiveApplication ($CurrentWindow)
    if ($isActiveCurrent -eq $False) {
      #Write-Host "skip not active windows"; Write-Host $CurrentWindow.Left; Write-Host ", "; Write-Host $CurrentWindow.Top; $CurrentWindow
      continue
    }
    foreach ($SetWindowData in $SetWindowDataArray) {
      #Write-Host "target data name"; Write-Host $SetWindowData.Name
      $isActiveData = IsActiveData ($SetWindowData)
      if ($isActiveData -eq $False) {
        #Write-Host "skip not active data"; Write-Host $SetWindowData.X; Write-Host ", "; Write-Host $SetWindowData.Y; $SetWindowData
        continue
      }
      $isEqual = IsEqualExplorerWindow ($SetWindowData) ($CurrentWindow)
      if ($isEqual -eq $True) {
        $isDetectChangeEqual = $True
        #Write-Host "detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
        ChangeApplicationWindow ($SetWindowData) ($CurrentWindow)
      } else {
        #Write-Host "don't detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
      }
    }
    if ($isDetectChangeEqual -eq $False) {
      # 一致するウィンドウが見つけられなかった
      # あいまい検索を実行
      #Write-Host "not detect equal"
    }
  }
}

filter IsActiveApplication($CurrentWindow) {
  # X,Y座標のどちらかが0未満だと最小化か別仮想デスクトップ上と判断
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
  # X,Y座標のどちらかが0未満だと最小化か別仮想デスクトップ上と判断
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

filter ChangeExplorerWindow($SetWindowData, $CurrentWindow) {
  #Write-Host "ChangeExplorerWindow() start"; Write-Host "SetWindowData"; Write-Host $SetWindowData; Write-Host "CurrentWindow"; Write-Host $CurrentWindow
  if ($CurrentWindow.Name -eq "Internet Explorer") {
    #Write-Host "change ie size"
    # サイズが3/2倍になり狂うので、2/3倍する。
    [Win32]::MoveWindow($CurrentWindow.HWND, $SetWindowData.X / 3 * 2, $SetWindowData.Y / 3 * 2, $SetWindowData.Width / 3 * 2, $SetWindowData.Height / 3 * 2, $true)
  #} elseif ($CurrentWindow.Name -eq "エクスプローラー") {
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

Param(
  [string]$Arg1 = $PSScriptRoot
)
$CurrentDirectory = $PSScriptRoot
#Write-Host $Arg1
#Split-Path $MyInvocation.MyCommand.Path
#$MyInvocation.MyCommand.Name
$FilePath = "$CurrentDirectory" + ".\explorer_windows.csv"

$Export = $True
$Inport = $False
#$Export = $False
#$Inport = $True

if ($Export -eq $True) {
  $rect = $null
  # IEは、タブが複数ある場合、サイズ変更できない。MoveWindowで実施する。
  $ProcessNames = @("エクスプローラー", "Internet Explorer")
  #$ProcessNames = @("エクスプローラー")
  Write-Host "ProcessNames: "; Write-Host $ProcessNames
  foreach($ProcessName in $ProcessNames) {
    Write-Host "ProcessName: "; Write-Host $ProcessName
  }
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

  $CurrentWindows = GetExplorerWindowEachFilter ($ProcessNames)
  #Write-Host "CurrentWindows"; Write-Host $CurrentWindows; $CurrentWindows
  SetExplorerWindowRect ($LoadWindowsApplicationDataArray) ($CurrentWindows)

  $appProcessName = @("*")
  GetApplicationWindow ($appProcessName) | Set-Variable GetApplicationDataArray
  #Write-Host "GetApplicationDataArray: "; Write-Host $GetApplicationDataArray; $GetApplicationDataArray
  SetApplicationWindowRect ($LoadWindowsApplicationDataArray) ($GetApplicationDataArray)
}
