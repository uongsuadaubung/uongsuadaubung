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

function CreateCmdFile {
    param (
        [string]$cmdFileName,
        [string]$jarProFile
    )

    $cmdContent = @"
@echo off
set JAR_PATH=%CD%\$jarProFile
set LOADER_PATH=%CD%\loader.jar
start /B javaw ^
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
            } else {
                $updatedContent += $line
            }
        }

        if (-not $keyExists) {
            # Nếu key chưa tồn tại, thêm mới
            $updatedContent += "${key}:$value"
        }

        $updatedContent | Set-Content -Path $versionFilePath
    } else {
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
                return $value -replace '\s+',''
            }
        }
    }

    # Nếu không tìm thấy key hoặc file không tồn tại, trả về giá trị mặc định (hoặc null)
    return $null
}

function CheckForUpdateBurp {
    param (
        [string]$Url
    )
    $request = Invoke-WebRequest -Uri $Url
    $content = $request.Content
    $pattern = '<title>(.*?)<\/title>'
    $match = [regex]::Match($content, $pattern);
    # Lấy giá trị từ kết quả tìm kiếm
    $version = $null;
    if ($match.Success) {
        $version = [regex]::Match($match.Value, "(\d+\.\d+(?:\.\d+)*)").Value
    } 
    return $version -replace '\s+',''
}

function CheckForUpdateLoader {
    param (
        [string]$url
    )
    $request = Invoke-WebRequest -Uri $url
    $content = $request.Content
    return $content -replace '\s+',''
}

function DownloadFile {
    param (
        [string]$url,
        [string]$outputName
    )
    Write-Output "Dowloading BurpSuite Professional."
    Write-Output "Please wait..."
	Write-Output $urlBurp
    # Thực hiện HTTP request và tải tệp về
    Invoke-WebRequest -Uri $url -OutFile $outputName
}

function CheckJava {
    $jre = Get-WmiObject -Class Win32_Product -filter "Vendor='Eclipse Adoptium'" | Where-Object Caption -clike "Eclipse Temurin JRE with Hotspot 21*"
    if (!$jre) {
        Write-Output "Please install jre first, run: ";
        Write-Output "winget install EclipseAdoptium.Temurin.21.JRE";
        # exit;
    }
    Write-Output "Required JRE-21 is Installed"
}

CheckJava
$urlLoaderVersion = "https://github.com/uongsuadaubung/uongsuadaubung/raw/main/version.txt";
$urlHtml = "https://portswigger.net/burp/releases/community/latest"

$versionFile = "version.txt"
$jarLatestFile = "jar_latest.jar"
$loaderLatestFile = "loader_latest.jar"
$jarProFile = "burpsuite_pro.jar"
$cmdFileName = "burpsuite_pro.cmd"
$loaderFile = "loader.jar"



# Lấy thông tin phiên bản mới nhất trên web
Write-Output "Checking for update..."

$loaderVerion = CheckForUpdateLoader -url $urlLoaderVersion
$urlLoader = "https://github.com/uongsuadaubung/uongsuadaubung/raw/${loaderVerion}/loader.jar"

$version = CheckForUpdateBurp -Url $urlHtml
if ($null -eq $version) {
    Write-Output "Something wrong, please check again."
    exit
}

$urlBurp = "https://portswigger-cdn.net/burp/releases/download?product=pro&version=$version&type=Jar"

# Kiểm tra xem file "version.txt" không tồn tại
if (-not (Test-Path $versionFile)) {
    #Nếu là lần đầu mới chưa có gì thì download loader và burp;
    DownloadFile -url $urlLoader -outputName $loaderFile
    DownloadFile -url $urlBurp -outputName $jarLatestFile
    # Tạo file "version.txt" và ghi giá trị $version vào đó
    CreateVersionFile -versionFilePath $versionFile -key $jarProFile -value $version
    CreateVersionFile -versionFilePath $versionFile -key $loaderFile -value $loaderVerion

	# Gọi function để quản lý tệp "burpsuite_pro.jar"
    ManageJarFiles -sourceJarFile $jarProFile -destinationJarFile $jarLatestFile
	Write-Output "BurpSuite Professional has been installed."
} else {
    # Đọc nội dung của file "version.txt"
    $currentVersion = ReadVersionFile -versionFilePath $versionFile -key $jarProFile 
    if ($null -eq $currentVersion) {
        Write-Output "Something wrong";
        exit;
    }
	Write-Output "Current verion: $currentVersion"
	Write-Output "Lastest verion: $version"
    # So sánh nội dung của file "version.txt" với $version
    if ($currentVersion -eq $version) {
        #Nội dung của file 'version.txt' trùng khớp với giá trị hiện tại: $version
        Write-Output "You are using the lastest version of BurpSuite Professional."
        
    } else {
        #Nội dung của file 'version.txt' không trùng khớp với giá trị hiện tại: $version
        DownloadFile -url $urlBurp -outputName $jarLatestFile
        # Gọi function để quản lý tệp "burpsuite_pro.jar"
        ManageJarFiles -sourceJarFile $jarProFile -destinationJarFile $jarLatestFile
		# Cập nhật lại phiên bản
        CreateVersionFile -versionFilePath $versionFile -key $jarProFile -value $version
		Write-Output "BurpSuite Professional has been updated."
		
    }

    #############################################################

    
    $currentLoaderVersion = ReadVersionFile -versionFilePath $versionFile -key $loaderFile 
    if ($null -eq $currentLoaderVersion) {
        Write-Output "Something wrong";
        exit;
    }
	Write-Output "Current loader verion: $currentLoaderVersion"
	Write-Output "Lastest loader verion: $loaderVerion"
    
    if ($currentLoaderVersion -eq $loaderVerion) {
       
        Write-Output "You are using the lastest version of Loader."
        
    } else {
        
        DownloadFile -url $urlLoader -outputName $loaderLatestFile
        
        ManageJarFiles -sourceJarFile $loaderFile -destinationJarFile $loaderLatestFile
		
        CreateVersionFile -versionFilePath $versionFile -key $loaderFile -value $loaderVerion
		Write-Output "Loader has been updated."
		
    }
}
  
if (-not (Test-Path $cmdFileName)) {
	# Gọi function để tạo tệp cmd
	CreateCmdFile -cmdFileName $cmdFileName -jarProFile $jarProFile
}

if (-not(Test-Path($loaderFile))) {
    DownloadFile -url $urlLoader -outputName $loaderFile
}

if (-not(Test-Path($jarProFile))) {
    DownloadFile -url $urlBurp -outputName $jarProFile
}



