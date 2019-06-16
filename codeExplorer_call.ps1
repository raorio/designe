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
      Write-Host $app.MainWindowTitle; Write-Host $app.MainWindowHandle
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

filter SetExplorerWindowRect($SetWindowDataArray, $CurrentWindowArray) {
  Write-Host "SetExplorerWindowRect() start"
  foreach ($CurrentWindow in $CurrentWindowArray) {
    $isDetectChangeEqual = $False
    foreach ($SetWindowData in $SetWindowDataArray) {
      $isEqual = IsEqualExplorerWindow ($SetWindowData) ($CurrentWindow)
      if ($isEqual -eq $True) {
        $isDetectChangeEqual = $True
        Write-Host "detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
        ChangeExplorerWindow ($SetWindowData) ($CurrentWindow)
      } else {
        Write-Host "don't detect equal"; Write-Host $SetWindowData.locationName; Write-Host $CurrentWindow.locationName
      }
    }
    if ($isDetectChangeEqual -eq $False) {
      # 一致するウィンドウが見つけられなかった
      # あいまい検索を実行
    }
  }
}

filter IsEqualExplorerWindow($SetWindowData, $CurrentWindow) {
  Write-Host "IsEqualExplorerWindow() start"; Write-Host "SetWindowData"; Write-Host $SetWindowData; Write-Host "CurrentWindow"; Write-Host $CurrentWindow
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
        Write-Host "equal window"; Write-Host $isEqualName; Write-Host $isEqualLocationName; Write-Host $isEqualLocationURL
        $isEqual = $True
        return $isEqual
      }
    }
  }
  Write-Host "not equal window"
  return $isEqual
}

filter ChangeExplorerWindow($SetWindowData, $CurrentWindow) {
  Write-Host "ChangeExplorerWindow() start"; Write-Host "SetWindowData"; Write-Host $SetWindowData; Write-Host "CurrentWindow"; Write-Host $CurrentWindow
  if ($CurrentWindow.Name -eq "Internet Explorer") {
    [Win32]::MoveWindow($CurrentWindow.HWND, $SetWindowData.X, $SetWindowData.Y, $SetWindowData.Width, $SetWindowData.Height, $true)
  } else {
    $CurrentWindow.Top = $SetWindowData.Y
    $CurrentWindow.Left = $SetWindowData.X
    $CurrentWindow.Width = $SetWindowData.Width
    $CurrentWindow.Height = $SetWindowData.Height
  }
}

# Helper
# ------

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

# C#
# --

Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  
  public class Win32 {
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
Write-Host "WindowName: "; Write-Host $WindowName
$PathName = ""
Write-Host "PathName: "; Write-Host $PathName

GetExplorerWindowRect ($ProcessNames) ($WindowName) ($PathName) | Set-Variable GetWindowsDataArray
Write-Host "GetWindowsDataArray: "; Write-Host $GetWindowsDataArray

$FilePath = ".\explorer_windows.csv"
ExportCSV ($GetWindowsDataArray) $FilePath

ImportCSV ($FilePath) | Set-Variable LoadWindowsDataArray
Write-Host "LoadWindowsDataArray: "; Write-Host $LoadWindowsDataArray; $LoadWindowsDataArray

$CurrentWindows = GetExplorerWindowEachFilter ($ProcessNames)
Write-Host "CurrentWindows"; Write-Host $CurrentWindows; $CurrentWindows
SetExplorerWindowRect ($LoadWindowsDataArray) ($CurrentWindows)

# IEのサイズ変更が、指定より大きくなる。メニュー等のサイズ分大きくなっている可能性有
