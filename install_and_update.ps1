function ManageJarFiles {
  param (
    [string]$sourceJarFile,
    [string]$destinationJarFile
  )

  # Kiểm tra xem tệp nguồn có tồn tại không
  if (Test-Path $sourceJarFile) {
    # Xoá tệp nguồn
    Remove-Item -Path $sourceJarFile -Force
  }

  # Đổi tên tệp đích thành tên tệp nguồn
  Rename-Item -Path $destinationJarFile -NewName $sourceJarFile
}

function CreateCmdBurpSuite {
  param (
    [string]$cmdFileName,
    [string]$jarProFile
  )
  if (Test-Path $cmdFileName) {
    # Đã tồn tại cmd thì bỏ qua
    return;
  }

  $cmdContent = @"
@echo off
set JAR_PATH=%CD%\$jarProFile
set LOADER_PATH=%CD%\loader.jar
set JAVA_PATH=%CD%\jre\bin
start /B %JAVA_PATH%\javaw.exe ^
    --add-opens=java.desktop/javax.swing=ALL-UNNAMED ^
    --add-opens=java.base/java.lang=ALL-UNNAMED ^
    --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED ^
    --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED ^
    --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED ^
    -javaagent:"%LOADER_PATH%" ^
    -noverify ^
    -jar "%JAR_PATH%"
"@

  Set-Content -Path $cmdFileName -Value $cmdContent
    
}

function CreateCmdLoader {
  $cmdFileName = "loader.bat"
  if (Test-Path $cmdFileName) {
    # Đã tồn tại cmd thì bỏ qua
    return;
  }
  
  $cmdContent = @"
@echo off
set LOADER_PATH=%CD%\loader.jar
set JAVA_PATH=%CD%\jre\bin
start /B %JAVA_PATH%\javaw.exe -jar %LOADER_PATH%
"@

  Set-Content -Path $cmdFileName -Value $cmdContent
}

function CreateVersionFile {
  param (
    [string]$versionFilePath,
    [string]$key,
    [string]$value
  )

  if (Test-Path -Path $versionFilePath) {
    $content = Get-Content -Path $versionFilePath
    $updatedContent = @()
    $keyExists = $false

    foreach ($line in $content) {
      if ($line -match "^${key}:") {
        # Nếu key đã tồn tại, cập nhật giá trị
        $updatedContent += "${key}:$value"
        $keyExists = $true
      }
      else {
        $updatedContent += $line
      }
    }

    if (-not $keyExists) {
      # Nếu key chưa tồn tại, thêm mới
      $updatedContent += "${key}:$value"
    }

    $updatedContent | Set-Content -Path $versionFilePath
  }
  else {
    # Nếu file không tồn tại, tạo mới file với key và value
    Set-Content -Path $versionFilePath -Value "${key}:$value"
  }
}

function ReadVersionFile {
  param (
    [string]$versionFilePath,
    [string]$key
  )

  if (Test-Path -Path $versionFilePath) {
    $content = Get-Content -Path $versionFilePath

    foreach ($line in $content) {
      if ($line -match "^${key}:") {
        # Nếu tìm thấy key, trả về giá trị
        $value = $line -replace "^${key}:", ""
        return $value -replace '\s+', ''
      }
    }
  }

  # Nếu không tìm thấy key hoặc file không tồn tại, trả về giá trị mặc định (hoặc null)
  return $null
}


function DownloadFile {
  param (
    [string]$url,
    [string]$outputName
  )
  Write-Output "Dowloading BurpSuite Professional."
  Write-Output "Please wait..."
  Write-Output $url
  # Thực hiện HTTP request và tải tệp về
  if (CheckProgramExists -name curl.exe) {
    curl.exe -o $outputName --location $url
  }
  else {
    Invoke-WebRequest -Uri $url -OutFile $outputName
  }
    
}


function CheckProgramExists {
  param (
    [string]$name
  )
  return Get-Command $name -ErrorAction SilentlyContinue    
}

function ReduceJarFile {
  param (
    [string]$jarProFile
  )
  $propertiesName = "chromium.properties"
  # Lấy thông tin về file
  $fileInfo = Get-Item $jarProFile

  # Dung lượng của file (dung lượng được tính bằng bytes)
  $fileSizeInBytes = $fileInfo.Length

  # Dung lượng trong megabytes
  $fileSizeInMB = $fileSizeInBytes / 1MB

  # Kiểm tra xem dung lượng có lớn hơn 400MB hay không
  if ($fileSizeInMB -lt 300) {
    Write-Output "No need to reduce jar size"
    return
  }
  # Kiểm tra xem 7z.exe có tồn tại trong đường dẫn môi trường không
  $7zPath = CheckProgramExists -name 7z.exe

  if ($7zPath) {
    Write-Output "7z.exe found. Proceeding with the script..."
        
    7z d $jarProFile chromium-linux64-*.zip chromium-macosx64-*.zip

    # Giải nén file abc.txt từ test.jar
    $unzippedContent = 7z e $jarProFile $propertiesName -so

    # Chuyển đổi nội dung thành mảng dòng
    $lines = $unzippedContent -split "`n"

    # Giữ lại chỉ dòng chứa "win64"
    $filteredLines = $lines | Where-Object { $_ -like "*win64*" }

    Write-Output $filteredLines

    Set-Content -Path "$propertiesName" -Value $filteredLines

    7z a $jarProFile $propertiesName

    Remove-Item $propertiesName

  }
  else {
    Write-Output "Error: 7z.exe not found. Please make sure 7-Zip is installed and added to the system PATH."
    Write-Output "winget install 7zip.7zip or winget install M2Team.NanaZip (recommended)"
  }
        
}

function CreateMenuShortcut {
  param(
    [string]$sourceFilePath
  )

  # Định nghĩa đường dẫn và tên của shortcut
  $ShortcutPath = "C:\Users\$env:username\AppData\Roaming\Microsoft\Windows\Start Menu\BurpSuite Professional.lnk"

  if (Test-Path($ShortcutPath)) {
    return;
  }

  # Tạo một đối tượng WScript.Shell
  $WScriptObj = New-Object -ComObject("WScript.Shell")

  # Tạo shortcut với đường dẫn đã xác định
  $shortcut = $WscriptObj.CreateShortcut($ShortcutPath)

  # Thêm đường dẫn đến file abc.bat vào shortcut
  $targetPath = "$pwd\$sourceFilePath"
  $shortcut.TargetPath = $targetPath
  $shortcut.WorkingDirectory = $pwd
  $shortcut.IconLocation = "$pwd\pro.ico"
  $Shortcut.WindowStyle = 7 #run minimized
  # Lưu shortcut
  $shortcut.Save()
  Write-Output "A shortcut has been created at the path $targetPath"
}

function RunBurpSuite {
  # Hiển thị thông điệp và yêu cầu xác nhận
  $response = Read-Host "Do you want to run BurpSuite now? (Y/N)"

  # Chuyển đổi đầu vào thành chữ hoa để so sánh dễ dàng
  $response = $response.ToUpper()

  # Kiểm tra xác nhận và thực hiện hành động tương ứng
  if ($response -eq 'Y') {
    Invoke-Item $cmdFileName
  }
  
}

function CheckForUpdateJava {
  param (
    [string]$versionFilePath
  )
  $Url = "https://adoptium.net/temurin/releases/"
  if (CheckProgramExists -name curl.exe) {
    $content = curl.exe --location $Url
  }
  else {
    $content = Invoke-RestMethod -Uri $Url
  }
  $zipFilePath = "jre.zip"
  $jrePath = "jre";
  $pattern = '<option value="(\d+)"[^>]*>\d+ - LTS<\/option>'
  $match = [regex]::Match($content, $pattern);
  # Lấy giá trị từ kết quả tìm kiếm
  $version = $null;
  if ($match.Success) {
    $version = [regex]::Match($match.Value, "\d+").Value
  } 
  
  $ltsVersion = $version -replace '\s+', ''
  Write-Output $ltsVersion
  $api = "https://api.adoptium.net/v3/assets/latest/$ltsVersion/hotspot?os=windows&image_type=jre"
  if (CheckProgramExists -name curl.exe) {
    $content = curl.exe --location $api
  }
  else {
    $content = Invoke-RestMethod -Uri $api
  }
  $content = $content | ConvertFrom-Json
  $jre = $content[0]
  $version = $jre.release_name
  $link = $jre.binary.package.link;

  $currentVersion = ReadVersionFile -key $jrePath -versionFilePath $versionFilePath
  Write-Output "Java Current verion: $currentVersion"
  Write-Output "Java Lastest verion: $version"
  if (($currentVersion -ne $version) -or (-not (Test-Path -Path $jrePath -PathType Container))) {
    

    #delete old version
    if (Test-Path -Path $jrePath -PathType Container) {
      # Nếu tồn tại, xoá thư mục "jre"
      Remove-Item -Path $jrePath -Recurse -Force
    }
    
    # handle update
    DownloadFile -url $link -outputName $zipFilePath
    # Kiểm tra xem tệp ZIP có tồn tại không
    if (Test-Path $zipFilePath -PathType Leaf) {
      7z x $zipFilePath
      # Xoá tệp ZIP
      Remove-Item -Path $zipFilePath -Force
    }

    # Kiểm tra xem thư mục cần đổi tên có tồn tại không
    if (Test-Path "${version}-${jrePath}" -PathType Container) {
      # Đổi tên thư mục
      Rename-Item -Path "${version}-${jrePath}" -NewName $jrePath
    }
    CreateVersionFile -versionFilePath $versionFilePath -key $jrePath -value $version
    Write-Output "Java $version has been installed."
  }
  else {
    Write-Output "You are using the lastest version of Java."
  }
}

function CheckForUpdateLoader {
  param (
    [string]$versionFilePath
  )
  $loaderFile = "loader.jar"
  $loaderLatestFile = "loader_latest.jar"
  $urlLoaderVersion = "https://github.com/uongsuadaubung/uongsuadaubung/raw/main/version.txt";
  if (CheckProgramExists -name curl.exe) {
    $content = curl.exe --location $urlLoaderVersion
  }
  else {
    $content = Invoke-RestMethod -Uri $urlLoaderVersion
  }
  $lastestVerion = $content -replace '\s+', ''
  $urlLoader = "https://github.com/uongsuadaubung/uongsuadaubung/raw/${lastestVerion}/loader.jar"

  $currentVersion = ReadVersionFile -versionFilePath $versionFile -key $loaderFile 
  
  Write-Output "Loader Current loader verion: $currentVersion"
  Write-Output "Loader Lastest loader verion: $lastestVerion"
    
  if (($currentVersion -ne $lastestVerion) -or (-not (Test-Path -Path $loaderFile))) {
    DownloadFile -url $urlLoader -outputName $loaderLatestFile
        
    ManageJarFiles -sourceJarFile $loaderFile -destinationJarFile $loaderLatestFile
		
    CreateVersionFile -versionFilePath $versionFile -key $loaderFile -value $lastestVerion
    Write-Output "Loader $lastestVerion has been installed."
    
  }
  else {
    Write-Output "You are using the lastest version of Loader."
  }

}

function CheckForUpdateBurpSuite {
  param (
    [string]$versionFilePath,
    [string]$jarProFile
  )
  $urlHtml = "https://portswigger.net/burp/releases/community/latest"
  $jarLatestFile = "jar_latest.jar"
 


  if (CheckProgramExists -name curl.exe) {
    $content = curl.exe --location $urlHtml
  }
  else {
    $content = Invoke-RestMethod -Uri $urlHtml
  }
    
  $pattern = '<title>(.*?)<\/title>'
  $match = [regex]::Match($content, $pattern);
  # Lấy giá trị từ kết quả tìm kiếm
  $v = "";
  if ($match.Success) {
    $v = [regex]::Match($match.Value, "(\d+\.\d+(?:\.\d+)*)").Value
  } 

  $version = $v -replace '\s+', ''
  
  $urlBurp = "https://portswigger-cdn.net/burp/releases/download?product=pro&version=$version&type=Jar"
  
  # Đọc nội dung của file "version.txt"
  $currentVersion = ReadVersionFile -versionFilePath $versionFile -key $jarProFile 
  
  Write-Output "BurpSuite Current verion: $currentVersion"
  Write-Output "BurpSuite Lastest verion: $version"
  # So sánh nội dung của file "version.txt" với $version
  if (($currentVersion -ne $version) -or (-not (Test-Path -Path $jarProFile))) {
    
    #Nội dung của file 'version.txt' không trùng khớp với giá trị hiện tại: $version
    DownloadFile -url $urlBurp -outputName $jarLatestFile
    # Gọi function để quản lý tệp "burpsuite_pro.jar"
    ManageJarFiles -sourceJarFile $jarProFile -destinationJarFile $jarLatestFile
    # Cập nhật lại phiên bản
    CreateVersionFile -versionFilePath $versionFile -key $jarProFile -value $version
    Write-Output "BurpSuite Professional $version has been installed."
        
  }
  else {
    #Nội dung của file 'version.txt' trùng khớp với giá trị hiện tại: $version
    Write-Output "You are using the lastest version of BurpSuite Professional."
    
  }

}

function RequireSevenZip {
  $7zPath = CheckProgramExists -name 7z.exe

  if (!$7zPath) {
    Write-Output "Error: 7z.exe not found. Please make sure 7-Zip is installed and added to the system PATH."
    Write-Output "winget install 7zip.7zip or winget install M2Team.NanaZip (recommended)"
    exit
  }
  
}

function DownloadIcon {
  
  $icon = "pro.ico"
  $urlIcon = "https://raw.githubusercontent.com/uongsuadaubung/uongsuadaubung/main/pro.ico"
  if (-not(Test-Path($icon))) {
    DownloadFile -url $urlIcon -outputName $icon
  }
}

#######Requirement
#Start
RequireSevenZip;
############define
$versionFile = "version.txt"
$jarProFile = "burpsuite_pro.jar"
$cmdFileName = "burpsuite_pro.cmd"
Write-Output "Checking for update..."



#############get resources
DownloadIcon;
#############check for update

CheckForUpdateBurpSuite -versionFilePath $versionFile -jarProFile $jarProFile;

CheckForUpdateLoader -versionFilePath $versionFile;

CheckForUpdateJava -versionFilePath $versionFile;

#################Cmd and Shortcut

CreateCmdBurpSuite -cmdFileName $cmdFileName -jarProFile $jarProFile

CreateCmdLoader

CreateMenuShortcut -sourceFilePath $cmdFileName
####### reduce size
ReduceJarFile -jarProFile $jarProFile
###last step
RunBurpSuite
