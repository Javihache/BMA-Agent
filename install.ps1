$curDir = Get-Location
$pm2InstallerFolder = "C:\Program Files\pm2-installer"
$pm2InstallerZipfile = "$HOME\Downloads\pm2-installer.zip"
$installationFolder = "C:\Program Files\Braiins-Manager-Agent"
# Define text color variables
# $RED = "Red"
# $GREEN = "Green"
# $YELLOW = "Yellow"
# $BLUE = "Blue"

function Message {
    param (
        [string]$Color,          # The color to use
        [string]$Message         # The message to display
    )

    Write-Host $Message -ForegroundColor $Color
}

# Define specific functions for each log level
function Info {
    param (
        [string]$Message
    )
    Message "Green" $Message
}

function Warning {
    param (
        [string]$Message
    )
    Message "Yellow" $Message
}

function Error {
    param (
        [string]$Message
    )
    Message "Red" $Message
}

function Debug {
    param (
        [string]$Message
    )
    Message "Blue" $Message
}


function ConfirmInstallation()
{
    $title = 'Braiins Manager Agent Installer'
    $question = "Welcome to the Braiins Manager Agent installer script.

This installer will download dependencies and install (or reinstall) a Braiins Manager Agent instance in a directory of your choice and its dependencies.

Braiins is not responsible for the undesired changes this script might do to your system.

Please review and understand this script before executing it and if you are not sure what it does, please get in touch with us by sending an e-mail to help@braiins.com.

Please confirm that you understand this script and you wish to proceed.

"
    $choices = '&Yes', '&No'
    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0)
    {
        Info "Proceeding with installation"
        # Get valid name and ID from the user
        $name = Get-ValidName
        $ID = Get-ValidID
        $nameLine = "name='$name'"
        $IDLine = "id='$ID'"
        InstallBraiinsManagerAgent
    }
    else
    {
        Error 'Ok. Exiting...'
        Start-Sleep -Seconds 1
        exit
    }
}


# Function to validate name input
function Get-ValidName() {
    while ($true) {
        Info "Braiins Manager Agent instance name (e.g., location, data center, or any unique name): "
        $name = Read-Host
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            return $name
        } else {
            Warning "Instance name cannot be empty."
        }
    }
}

# Function to validate ID input against the UUID regex pattern
function Get-ValidID() {
    $regex = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    while ($true) {
        Info "Enter your Braiins Manager Agent ID (UUID Format): "
        $ID = Read-Host 
        if (-not [string]::IsNullOrWhiteSpace($ID) -and $ID -match $regex) {
            return $ID
        } else {
            Warning "Invalid Agent ID. Value does not match the UUID format."
        }
    }
}

function Create_Env_File() {
    cd $installationFolder
    $outputFile = "$installationFolder\.env.config"
    Set-Content -Path $outputFile -Value "$nameLine`r`n$IDLine"
}

# Write the validated inputs to the file in the specified format
function Install_NodeJS {

    if (-NOT (Get-Command node -ErrorAction SilentlyContinue)) {
          #Install Winget if not present
        if ((Get-Command winget -ErrorAction SilentlyContinue)) { 
            try {
                Info "Attempting to install NodeJS using Winget"
                winget install -h OpenJS.NodeJS.LTS
            }
            catch {
                Debug "Winget is not installed in this Windows system. Trying to install NodeJS with MSI packages."
                $msiUrl = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
                # Remember to update this hardcoded link to the next major version of NodeJS in the future.
                $localMsiPath = "$env:TEMP\node-v20.18.0-x64.msi"
                Invoke-WebRequest -Uri $msiUrl -OutFile $localMsiPath
                Start-Process msiexec.exe -ArgumentList "/i `"$localMsiPath`" /quiet /norestart" -Wait
                Remove-Item $localMsiPath
            }
            finally {
                Info "NodeJS succesfully installed! Proceeding..."
            }
        }
    else {
        Info "NodeJS is already installed! Proceeding..."
    }     
    }
}

function InstallBraiinsManagerAgent()
{
    $start_time = Get-Date

    # Check for admin rights
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
    {
        Write-Warning "This setup needs Administrator permissions. Please run this installer on a Powershell as Administrator."
        exit 1
    }
    #Select folder and install the files
    if (-NOT Test-Path -Path $installationFolder) {
        Info "Braiins Manager Agent will be installed in $installationFolder"
    } else {
        while ($true) {
            # Prompt the user for the installation folder
            $installationFolder = Select-Folder
            # Break the loop if the user pressed Cancel in the folder dialog
            if ($null -eq $installationFolder)
            {
                Write-Host "Installation canceled by the user."
                exit
            }

            # Ensure the folder exists before checking contents
            if (Test-Path -Path $installationFolder)
            {

                # Use [IO.Directory]::GetFiles() to check for files in the folder
                $filesInFolder = [System.IO.Directory]::GetFiles($installationFolder)
                if ($filesInFolder.Count -eq 0)
                {
                    Write-Host "$installationFolder is empty. Proceeding with installation."
                    break
                }
                else
                {
                    Write-Host "$installationFolder not empty. Please choose an empty folder to install."
                }
            }
            else
            {
                Write-Host "The selected folder does not exist. Please choose a valid folder."
            }
        }

    }
    #Install NodeJS and PM2
    Install_NodeJS
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (-NOT (Get-Command pm2 -ErrorAction SilentlyContinue)) {
        npm install -global pm2
    }   
    #Install PM2-installer by jessety
    CheckPM2Installer
    pm2 update
    
    # Proceed with the rest of the script
    Write-Host "Proceeding with installation in folder: $installationFolder"
    Create_Env_File
    $distZipfile = Join-Path -Path $installationFolder -ChildPath krater-node.zip
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/dist.zip  -OutFile $distZipfile
    Expand-Archive -path $distZipfile -DestinationPath $installationFolder -Force
    Remove-Item -Force $distZipfile
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/package.json -OutFile $installationFolder\package.json
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/package-lock.json -OutFile $installationFolder\package-lock.json
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/onboarding.js -OutFile $installationFolder\onboarding.js
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/pm2.config.js -OutFile $installationFolder\pm2.config.js
    Start-Process -FilePath "npm" -ArgumentList "--silent ci" -WorkingDirectory $installationFolder -Wait -NoNewWindow
    pm2 -s start pm2.config.js --time --exp-backoff-restart-delay=3000
    pm2 -s save
    cd $curDir
    Info "
Installation completed in: $( (Get-Date).Subtract($start_time).Seconds ) seconds.

Braiins Manager Agent has been successfully installed and will start on boot!

Please use command 'pm2' and the corresponding arguments to start, stop and restart Braiins Manager Agent. 
You can do 'pm2 --help' to obtain more information"

}

function Select-Folder
{

    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $browse = New-Object System.Windows.Forms.FolderBrowserDialog
    $browse.SelectedPath = "C:\"
    $browse.ShowNewFolderButton = $true
    $browse.Description = "Select the Folder to install Braiins Manager Agent. DO NOT use a folder inside C:/Users or Braiins Manager Agent won't work"

    if ($browse.ShowDialog() -eq "OK")
    {

        return $browse.SelectedPath

    }
    else
    {

        $res = [System.Windows.Forms.MessageBox]::Show("You clicked Cancel. Would you like to try again or exit?", "Select a location", [System.Windows.Forms.MessageBoxButtons]::RetryCancel)
        if ($res -eq "Cancel")
        {
            #User cancelled, therefore clean up and exit the script.
            ConfirmUninstallpm2installer
            ConfirmUninstallNodeJS
            return $null
        }
        else
        {

            return Select-Folder

        }
    }
}

function CheckPM2Installer
{

    if (Test-Path -PathType Container $pm2InstallerFolder)
    {
        cd $pm2InstallerFolder
        try
        {

            Start-Process -FilePath "npm" -ArgumentList "run configure --silent" -WorkingDirectory $pm2InstallerFolder\pm2-installer-main -Wait -NoNewWindow
        }
        catch
        {

            Remove-Item -Path $pm2InstallerFolder -Recurse | Out-Null
            InstallPM2Installer

        }


    }
    else
    {

        InstallPM2Installer

    }

    cd $curDir
    $Env:PM2_HOME = "C:\ProgramData\pm2\home"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function InstallPM2Installer()
{
    New-Item -Path $pm2InstallerFolder -ItemType Directory | Out-Null
    Invoke-WebRequest -Uri https://github.com/jessety/pm2-installer/archive/main.zip -OutFile $pm2InstallerZipfile
    Expand-Archive -path $pm2InstallerZipfile -DestinationPath $pm2InstallerFolder
    Remove-Item -Force $pm2InstallerZipfile
    Start-Process -FilePath "npm" -ArgumentList "run configure --silent" -WorkingDirectory $pm2InstallerFolder\pm2-installer-main -Wait -NoNewWindow
    Start-Process -FilePath "npm" -ArgumentList "run setup --silent" -WorkingDirectory $pm2InstallerFolder\pm2-installer-main -Wait -NoNewWindow
}

function ConfirmUninstallNodeJS()
{

    $title = 'Braiins Manager Agent Uninstaller'
    $question = "Would you like to remove NodeJS from your system?"
    $choices = '&Yes', '&No'
    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0)
    {
        Write-Host '
    Uninstalling NodeJS'-ForegroundColor Green
        Remove-NodeJS
    }
    else
    {
        Write-Host 'Ok. skipping...'-ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }
}

function ConfirmUninstallpm2installer()
{

    $title = 'Braiins Manager Agent Uninstaller'
    $question = "Would you like to remove pm2-installer from your system?
    pm2-installer manages pm2 and helps the Braiins Manager Agent process to start on boot.
    If you still have other Braiins Manager Agent instances running, you should choose 'no'"
    $choices = '&Yes', '&No'
    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0)
    {
        Write-Host '
    Removing pm2-installer'-ForegroundColor Green
        Remove-pm2installer
    }
    else
    {
        Write-Host 'Ok. skipping...'-ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }
}

function Remove-pm2installer()
{

    if (test-path -PathType Container $pm2InstallerFolder)
    {
        cd $pm2InstallerFolder
        Start-Process -FilePath "npm" -ArgumentList "--silent run deconfigure" -WorkingDirectory $pm2InstallerFolder -Wait -NoNewWindow
        Start-Process -FilePath "npm" -ArgumentList "--silent run remove" -WorkingDirectory $pm2InstallerFolder -Wait -NoNewWindow
        cd $curDir
        Remove-Item -Path $pm2InstallerFolder -Recurse | Out-Null
    }
}

Function Remove-NodeJS()
{

    if (Get-Command node -ErrorAction SilentlyContinue)
    {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        winget remove OpenJS.NodeJS.LTS
    }
}

ConfirmInstallation
