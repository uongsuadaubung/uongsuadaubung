function ManageJarProFile {
    param (
        [string]$jarProFile,
        [string]$jarLatestFile
    )

    # Kiểm tra xem file "burpsuite_pro.jar" có tồn tại không
    if (Test-Path $jarProFile) {
        # Xoá file "burpsuite_pro.jar"
        Remove-Item -Path $jarProFile -Force
        
    }

    # Đổi tên "jar_latest.jar" thành "burpsuite_pro.jar"
    Rename-Item -Path $jarLatestFile -NewName $jarProFile
    
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
        [string]$version
    )

    Set-Content -Path $versionFilePath -Value $version
    
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
    $version = "0";
    if ($match.Success) {
        $version = [regex]::Match($match.Value, "(\d+\.\d+(?:\.\d+)*)").Value
    } 
    return $version -replace '\s+',''
}

function DownloadFile {
    param (
        [string]$url,
        [string]$outputName
    )
    Write-Output "Dowloading BurpSuite Professional."
    Write-Output "Please wait..."
    # Thực hiện HTTP request và tải tệp về
    Invoke-WebRequest -Uri $url -OutFile $outputName
}

function CheckJava {
    $jre = Get-WmiObject -Class Win32_Product -filter "Vendor='Eclipse Adoptium'" | Where-Object Caption -clike "Eclipse Temurin JRE with Hotspot 21*"
    if (!$jre) {
        Write-Output "Please install jre first, run: ";
        Write-Output "winget install EclipseAdoptium.Temurin.21.JRE";
        # exit;
    }else{
        Write-Output "Required JRE-21 is Installed"
    }
    
}

CheckJava

$urlHtml = "https://portswigger.net/burp/releases/professional-community-2023-10-2-4?requestededition=professional"
$url = "https://portswigger.net/burp/releases/startdownload?product=pro&version=&type=Jar"
$urlLoader = "https://github.com/uongsuadaubung/uongsuadaubung/raw/1.17/loader.jar"
$versionFile = "version.txt"
$jarLatestFile = "jar_latest.jar"
$jarProFile = "burpsuite_pro.jar"
$cmdFileName = "burpsuite_pro.cmd"
$loaderFile = "loader.jar"



# Lấy thông tin phiên bản mới nhất trên web
Write-Output "Checking for update..."
$version = CheckForUpdateBurp -Url $urlHtml

if ($version -eq "0") {
    Write-Output "Something wrong, please check again."
    exit
}




# Kiểm tra xem file "version.txt" không tồn tại
if (-not (Test-Path $versionFile)) {
    DownloadFile -url $url -outputName $jarLatestFile
    # Tạo file "version.txt" và ghi giá trị $version vào đó
    CreateVersionFile -versionFilePath $versionFile -version $version
	# Gọi function để quản lý tệp "burpsuite_pro.jar"
    ManageJarProFile -jarProFile $jarProFile -jarLatestFile $jarLatestFile
	Write-Output "BurpSuite Professional has been installed."
} else {
    # Đọc nội dung của file "version.txt"
    $currentVersion = (Get-Content $versionFile) -replace '\s+',''
	Write-Output "Current verion: $currentVersion"
	Write-Output "Lastest verion: $version"
    # So sánh nội dung của file "version.txt" với $version
    if ($currentVersion -eq $version) {
        #Nội dung của file 'version.txt' trùng khớp với giá trị hiện tại: $version
        Write-Output "You are using the lastest version of BurpSuite Professional."
        
    } else {
        #Nội dung của file 'version.txt' không trùng khớp với giá trị hiện tại: $version
        DownloadFile -url $url -outputName $jarLatestFile
        # Gọi function để quản lý tệp "burpsuite_pro.jar"
        ManageJarProFile -jarProFile $jarProFile -jarLatestFile $jarLatestFile
		# Cập nhật lại phiên bản
		CreateVersionFile -versionFilePath $versionFile -version $version
		Write-Output "BurpSuite Professional has been updated."
		
    }
}

if (-not (Test-Path $cmdFileName)) {
	# Gọi function để tạo tệp cmd
	CreateCmdFile -cmdFileName $cmdFileName -jarProFile $jarProFile
}

if (-not(Test-Path($loaderFile))) {
    DownloadFile -url $urlLoader -outputName $loaderFile
}