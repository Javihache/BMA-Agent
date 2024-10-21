$curDir = Get-Location
$pm2InstallerFolder = "C:\Program Files\pm2-installer"
$pm2InstallerZipfile = "$HOME\Downloads\pm2-installer.zip"

function ConfirmInstallation()
{
    $title = 'Braiins Manager Agent Installer'
    $question = "Welcome to the Braiins Manager Agent installer script.

This installer will download dependencies and install (or reinstall) a Braiins Manager Agent instance in a directory of your choice and its dependencies.

Braiins is not responsible for the undesired changes this script might do to your system.

Please review and understand this script before executing it and if you are not sure what it does, please get in touch with us by sending an e-mail to help@braiins.com.

Please confirm that you understand this script and you wish to proceed."
    $choices = '&Yes', '&No'
    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0)
    {
        Write-Host 'Proceeding with installation'-ForegroundColor Green
        InstallBraiinsManagerAgent
    }
    else
    {
        Write-Host 'Ok. Exiting...'-ForegroundColor Red
        Start-Sleep -Seconds 1
        exit
    }
}

function InstallBraiinsManagerAgent()
{
    $start_time = Get-Date

    # Check for admin rights
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
    {
        write-Warning "This setup needs Administrator permissions. Please run this installer on a Powershell as Administrator."
        Start-Sleep -Seconds 1
        exit
    }

    #Install Winget if not present
    if (-NOT (Get-Command winget -ErrorAction SilentlyContinue))
    {
        Install-WinGet
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    #Install NodeJS and PM2
    if (-NOT (Get-Command node -ErrorAction SilentlyContinue))
    {
        winget install -h OpenJS.NodeJS.LTS
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    npm install -global pm2

    #Install PM2-installer by jessety
    CheckPM2Installer
    pm2 update

    #Select folder and install the files
    while ($true)
    {
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
                Write-Host "The folder is empty. Proceeding with installation."
                break
            }
            else
            {
                Write-Host "The folder is not empty. Please choose an empty folder to install."
            }
        }
        else
        {
            Write-Host "The selected folder does not exist. Please choose a valid folder."
        }
    }
    # Proceed with the rest of the script
    Write-Host "Proceeding with installation in folder: $installationFolder"
    cd $installationFolder
    $distZipfile = Join-Path -Path $installationFolder -ChildPath krater-node.zip
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/dist.zip  -OutFile $distZipfile
    Expand-Archive -path $distZipfile -DestinationPath $installationFolder -Force
    Remove-Item -Force $distZipfile
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/package.json -OutFile $installationFolder\package.json
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/package-lock.json -OutFile $installationFolder\package-lock.json
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/onboarding.js -OutFile $installationFolder\onboarding.js
    Invoke-WebRequest -Uri https://braiinspublic.blob.core.windows.net/agent/pm2.config.js -OutFile $installationFolder\pm2.config.js
    Start-Process -FilePath "npm" -ArgumentList "--silent ci" -WorkingDirectory $installationFolder -Wait -NoNewWindow
    New-Item -Path $installationFolder\.env.config -ItemType File | Out-Null
    cd $installationFolder
    node $installationFolder\onboarding.js
    pm2 -s start pm2.config.js --time --exp-backoff-restart-delay=3000
    pm2 -s save
    cd $curDir
    write-Host "
Installation completed in: $( (Get-Date).Subtract($start_time).Seconds ) seconds.

Braiins Manager Agent has been successfully installed and will start on boot!

Please use command 'pm2' and the corresponding arguments to start, stop and restart Braiins Manager Agent. 
You can do 'pm2 --help' to obtain more information"-ForegroundColor Green

}

Function Install-WinGet
{
    #Install the latest package from GitHub
    [cmdletbinding(SupportsShouldProcess)]
    [alias("iwg")]
    [OutputType("None")]
    [OutputType("Microsoft.Windows.Appx.PackageManager.Commands.AppxPackage")]
    Param(
        [Parameter(HelpMessage = "Display the AppxPackage after installation.")]
        [switch]$Passthru
    )

    Write-Verbose "[$( (Get-Date).TimeofDay )] Starting $( $myinvocation.mycommand )"

    if ($PSVersionTable.PSVersion.Major -eq 7)
    {
        Write-Warning "This command does not work in PowerShell 7. You must install in Windows PowerShell."
        return
    }

    #test for requirement
    $Requirement = Get-AppPackage "Microsoft.DesktopAppInstaller"
    if (-Not $requirement)
    {
        Write-Verbose "Installing Desktop App Installer requirement"
        Try
        {
            Add-AppxPackage -Path "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -erroraction Stop
        }
        Catch
        {
            Throw $_
        }
    }

    $uri = "https://api.github.com/repos/microsoft/winget-cli/releases"

    Try
    {
        Write-Verbose "[$( (Get-Date).TimeofDay )] Getting information from $uri"
        $get = Invoke-RestMethod -uri $uri -Method Get -ErrorAction stop

        Write-Verbose "[$( (Get-Date).TimeofDay )] getting latest release"
        #$data = $get | Select-Object -first 1
        $data = $get[0].assets | Where-Object name -Match 'msixbundle'
        $appx = $data.browser_download_url
        #$data.assets[0].browser_download_url
        Write-Verbose "[$( (Get-Date).TimeofDay )] $appx"
        If ( $pscmdlet.ShouldProcess($appx, "Downloading asset"))
        {
            $file = Join-Path -path $env:temp -ChildPath $data.name

            Write-Verbose "[$( (Get-Date).TimeofDay )] Saving to $file"
            Invoke-WebRequest -Uri $appx -UseBasicParsing -DisableKeepAlive -OutFile $file

            Write-Verbose "[$( (Get-Date).TimeofDay )] Adding Appx Package"
            Add-AppxPackage -Path $file -ErrorAction Stop

            if ($passthru)
            {
                Get-AppxPackage microsoft.desktopAppInstaller
            }
        }
    } #Try
    Catch
    {
        Write-Verbose "[$( (Get-Date).TimeofDay )] There was an error."
        Throw $_
    }
    Write-Verbose "[$( (Get-Date).TimeofDay )] Ending $( $myinvocation.mycommand )"
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
