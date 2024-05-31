param($sourceZipUrl="", $destinationFolder="", $installOptions="Chrome")
Start-Transcript "C:\scriptlog.txt"
$ErrorActionPreference = 'SilentlyContinue'

# Function to download files
function Download-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$url,
        [Parameter(Mandatory = $true)]
        [string]$output
    )

    $client = New-Object System.Net.WebClient
    $client.DownloadFile($url, $output)
}

# Add to the PATH
function Add-Path {
    param (
        [string]$path
    )
    if (-not ($env:Path -contains $path)) {
        Write-Output "Adding [$path] to the PATH..."
        $env:Path += ";$path"
    }
}

if([string]::IsNullOrEmpty($sourceZipUrl) -eq $false -and [string]::IsNullOrEmpty($destinationFolder) -eq $false)
{
    if((Test-Path $destinationFolder) -eq $false)
    {
        Write-Output "Creating destination folder $destinationFolder"
        New-Item -Path $destinationFolder -ItemType directory
    }
    $splitpath = $sourceZipUrl.Split("/")
    $fileName = $splitpath[$splitpath.Length-1]
    $destinationPath = Join-Path $destinationFolder $fileName

    Write-Output "Starting download: $sourceZipUrl to $destinationPath"
    Download-File -url $sourceZipUrl -output $destinationPath

    Write-Output "Unzipping $destinationPath to $destinationFolder"
    (new-object -com shell.application).namespace($destinationFolder).CopyHere((new-object -com shell.application).namespace($destinationPath).Items(),16)
}

# Disable IE ESC
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
Stop-Process -Name Explorer

# Hide Server Manager
$HKLM = "HKLM:\SOFTWARE\Microsoft\ServerManager"
New-ItemProperty -Path $HKLM -Name "DoNotOpenServerManagerAtLogon" -Value 1 -PropertyType DWORD
Set-ItemProperty -Path $HKLM -Name "DoNotOpenServerManagerAtLogon" -Value 1 -Type DWord


# ############################################################
function Install-Terraform {
     # Set the URL to check the latest Terraform version
        $latestReleaseUrl = "https://api.github.com/repos/hashicorp/terraform/releases/latest"

        # Define the installation directory
        $installDir = "C:\Terraform"

        # Create the installation directory if it does not exist
        if (-Not (Test-Path -Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir
        }

        # Check for the latest version
        Write-Output "Checking for the latest Terraform version..."
        $latestVersionResponse = Invoke-RestMethod -Uri $latestReleaseUrl
        $latestVersion = $latestVersionResponse.tag_name.TrimStart("v")

        Write-Output "Latest Terraform version is $latestVersion"

        # Construct the download URL for the Windows 64-bit binary
        $downloadUrl = "https://releases.hashicorp.com/terraform/$latestVersion/terraform_${latestVersion}_windows_amd64.zip"

        # Define the paths for the downloaded zip file and the executable
        $zipPath = "$installDir\terraform.zip"
        $exePath = "$installDir\terraform.exe"

        # Download the latest Terraform zip file
        Write-Output "Downloading Terraform $latestVersion..."
        Download-File -url $downloadUrl -output $zipPath

        # Extract the Terraform executable
        Write-Output "Extracting Terraform executable..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $installDir)

        # Cleanup the zip file
        Remove-Item -Path $zipPath

        # Add Terraform to the PATH
        Add-Path $installDir

        Write-Output "Terraform $latestVersion installation completed."
        # Write-Output "You may need to restart your terminal or system for the changes to take effect."
}

function Install-Git {
    # Define the URL to check the latest Git for Windows version
    $latestReleaseUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"

    # Check for the latest version
    Write-Output "Checking for the latest Git for Windows version..."
    $latestVersionResponse = Invoke-RestMethod -Uri $latestReleaseUrl
    $latestVersion = $latestVersionResponse.tag_name.TrimStart("v")

    Write-Output "Latest Git for Windows version is $latestVersion"

    # Construct the download URL for the Windows 64-bit installer
    $downloadUrl = $latestVersionResponse.assets | Where-Object { $_.name -like '*-64-bit.exe' } | Select-Object -ExpandProperty browser_download_url

    # Define the path for the downloaded installer
    $installerPath = "$env:TEMP\Git-$latestVersion-64-bit.exe"

    # Download the latest Git installer
    Write-Output "Downloading Git for Windows $latestVersion..."
    Download-File -url $downloadUrl -output $installerPath

    # Install Git
    Write-Output "Installing Git for Windows $latestVersion..."
    Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT", "/NORESTART" -Wait

    # Cleanup the installer
    Remove-Item -Path $installerPath

    Write-Output "Git for Windows $latestVersion installation completed."
}

# Function to install a VSCode extension
function Install-VSCodeExtension {
    param (
        [Parameter(Mandatory = $true)]
        [string]$extensionName
    )

    # Check if code command is available
    if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
        Write-Output "VSCode CLI (code) not found in PATH. Please ensure VSCode is installed and 'code' is added to the PATH."
        return
    }

    # Install the extension
    Write-Output "Installing VSCode extension: $extensionName"
    $result = code --install-extension $extensionName

    if ($LASTEXITCODE -eq 0) {
        Write-Output "Extension $extensionName installed successfully."
    } else {
        Write-Output "Failed to install extension $extensionName. Error: $result"
    }
}

function Install-NodeJS {
    $nodeJsUrlRoot = "https://nodejs.org/dist/latest"
    # URL to get the latest Node.js version number
    $nodeJsLatestUrl = "$nodeJsUrlRoot/SHASUMS256.txt"

    # Path to download the installer
    $installerPath = "$env:TEMP\nodejs.msi"

    # Get the latest Node.js version number
    Write-Output "Fetching the latest Node.js version..."
    $latestVersionResponse = Invoke-RestMethod -Uri $nodeJsLatestUrl
    $latestVersion = ($latestVersionResponse -split "\n") -match 'node-v(\d+\.\d+\.\d+)-x64.msi'
    $latestVersion = ($latestVersion -split " ")[2]

    Write-Output "Latest Node.js version is $latestVersion"

    # Construct the download URL for the Windows 64-bit MSI installer
    $downloadUrl = "$nodeJsUrlRoot/$latestVersion"

    # Download the latest Node.js installer
    Write-Output "Downloading Node.js $latestVersion..."
    Download-File -url $downloadUrl -output $installerPath

    # Install Node.js
    Write-Output "Installing Node.js $latestVersion..."
    Start-Process -FilePath $installerPath -ArgumentList "/quiet" -Wait

    # Cleanup the installer
    Remove-Item -Path $installerPath

    Write-Output "Node.js $latestVersion installation completed."

    # Add Node.js to the PATH
    Add-Path "C:\Program Files\nodejs"
}

function Install-Python {
    # # URL to get the latest Python release page
    $pythonReleaseUrl = "https://www.python.org/ftp/python/"

    # # Path to download the installer
    $installerPath = "$env:TEMP\python-installer.exe"

    # # Get the latest Python version number
    # Write-Output "Fetching the latest Python version..."
    # $latestVersionPage = Invoke-RestMethod -Uri $pythonReleaseUrl | Select-Object -ExpandProperty Content
    # $latestVersion = ($latestVersionPage -split "`n") -match 'href="(\d+\.\d+\.\d+)/"' | ForEach-Object { $_ -match 'href="(\d+\.\d+\.\d+)/"' ; $matches[1] } | Sort-Object -Descending | Select-Object -First 1
    $latestVersion = "3.12.3"
    # Write-Output "Latest Python version is $latestVersion"

    # Construct the download URL for the Windows 64-bit installer
    $downloadUrl = "$pythonReleaseUrl$latestVersion/python-$latestVersion-amd64.exe" # "$pythonReleaseUrl$latestVersion/python-$latestVersion-amd64.exe"

    # Download the latest Python installer
    Write-Output "Downloading Python $latestVersion..."
    Download-File -url $downloadUrl -output $installerPath

    # Install Python
    Write-Output "Installing Python $latestVersion..."
    $installedPath = "C:\Program Files\Python"
    Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 TargetDir=""$installedPath""" -Wait

    # Cleanup the installer
    Remove-Item -Path $installerPath

    Write-Output "Python $latestVersion installation completed."

    # Add Python to the PATH
    Add-Path $installedPath

    # Install pip
    py -m ensurepip --upgrade

    # Add pip to the PATH
    Add-Path "$installedPath\Scripts"
}


# Optionally install additional software
if([string]::IsNullOrEmpty($installOptions) -eq $false) 
{
    if($installOptions.Contains("VSCode")) 
    {
        # Install VS Code
        $Path = $env:TEMP; 
        $Installer = "vscode.exe"
        Write-Output "Downloading VSCode installer"
        Invoke-WebRequest "https://go.microsoft.com/fwlink/?Linkid=852157" -OutFile $Path\$Installer
        Write-Output "Installing VSCode from $Path\$Installer..."
        Start-Process -FilePath $Path\$Installer -Args "/verysilent /MERGETASKS=!runcode" -Verb RunAs -Wait
        Remove-Item $Path\$Installer

        # Add VSCode to the PATH
        Add-Path "C:\Program Files\Microsoft VS Code\bin"
    }

    if($installOptions.Contains("Git")) 
    {
        # Install Git
        Install-Git
        # $Path = $env:TEMP; 
        # $Installer = "Git-2.45.1-64-bit.exe"
        # Write-Output "Downloading Git Client"
        # Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.45.1.windows.1/Git-2.45.1-64-bit.exe" -OutFile $Path\$Installer
        # Write-Host "Installing Git Client from $Path\$Installer..." -ForegroundColor Green
        # Start-Process -FilePath msiexec -Args "/i $Path\$Installer /quiet /qn /norestart" -Verb RunAs -Wait
        # Remove-Item $Path\$Installer
    }

    if($installOptions.Contains("PowerShell")) 
    {
        # Create a PowerShell ISE Shortcut on the Desktop
        Write-Output "Creating PowerShell ISE shortcut"
        $WshShell = New-Object -ComObject WScript.Shell
        $allUsersDesktopPath = "$env:SystemDrive\Users\Public\Desktop"
        New-Item -ItemType Directory -Force -Path $allUsersDesktopPath
        $Shortcut = $WshShell.CreateShortcut("$allUsersDesktopPath\PowerShell ISE.lnk")
        $Shortcut.TargetPath = "$env:windir\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe"
        $Shortcut.Save()  
    }

    if($installOptions.Contains("NodeJS")) 
    {
        Install-NodeJS
    }

    if($installOptions.Contains("Python")) 
    {
        Install-Python
        if($installOptions.Contains("VSCode")) 
        {
            Install-VSCodeExtension -extensionName "ms-python.python"
        }
    }

    if($installOptions.Contains("AzureCLI")) 
    {
        # Install Azure CLI 2
        $Path = $env:TEMP; 
        $Installer = "cli_installer.msi"
        Write-Output "Downloading Azure CLI installer"
        Invoke-WebRequest "https://aka.ms/InstallAzureCliWindows" -OutFile $Path\$Installer
        Write-Output "Installing Azure CLI from $Path\$Installer..."
        Start-Process -FilePath msiexec -Args "/i $Path\$Installer /quiet /qn /norestart" -Verb RunAs -Wait
        Remove-Item $Path\$Installer

        if($installOptions.Contains("VSCode")) 
        {
            Install-VSCodeExtension -extensionName "ms-vscode.azurecli"
        }
    }

    if($installOptions.Contains("AzurePowerShell")) 
    {
        # Install Azure PowerShell
        Write-Output "Installing NuGet package provider"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

        Write-Output "Installing Az PowerShell module"
        Install-Module -Name Az -AllowClobber -Scope AllUsers -Force -Confirm:$false
    }

    if($installOptions.Contains("Terraform")) 
    {
        Install-Terraform
        if($installOptions.Contains("VSCode")) 
        {
            Install-VSCodeExtension -extensionName "hashicorp.terraform"
        }
    }
}

Stop-Transcript