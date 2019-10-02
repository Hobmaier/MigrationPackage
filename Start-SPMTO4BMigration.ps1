<#
.SYNOPSIS
    Migrate to Microsoft OneDrive using SPMT
.DESCRIPTION
    Use this script for personal Home folder to OneDrive Migration.
    IMPORTANT: Make Sure drive letter Z: is free as it will be used by the script for disk space check
.EXAMPLE
    .\Start-SPMTO4BMigration.ps1 -SourceDirectory c:\temp\alans -DestinationDirectory c:\temp\alans_test -UseMFAAuthentication -Users alans@avengers.hobi.ws -Tenant theavengers
.EXAMPLE
    .\Start-SPMTO4BMigration.ps1 -SourceDirectory c:\temp\users -UseMFAAuthentication -Users alans@avengers.hobi.ws -Tenant contoso -UsersProfileMode
.EXAMPLE
    $key = <Azure Storage Account Key>
    $account = <Azure Storage Account name>
    .\Start-SPMTO$BMigration.ps1 -SourceDirectory c:\temp\users -UsersProfileMode -Tenant contoso -CustomStorageAccountName $account -CustomStorageAccountKey $key -CSVFilePath c:\migration\usersUPN.csv
.NOTES
   Changelog
   ToDo: By default MigrateFilesAndFoldersWithInvalidChars is false (for Performance)
   ToDo: Single User mode doesn't care about O4B_NotMigrated folder (trash)

   V 2.0 - 02.10.2019: Fix: Single user mode fix when creating the log, just before move
   V 1.9 - 10.09.2019: Fix: Increased timeout after initial OneDrive Creation from 5 up to 120 seconds
   V 1.8 - 17.07.2019: Fix: Now cache SharePoint sites before the users loop, before that no cache
   V 1.7 - 17.07.2019: New: Exclude *.pst.tmp from robocopy because Outlook temp file
   V 1.6 - 11.07.2019: Fix: Decreased robocopy timeout from 60 to 1 second and retry from 5 to 0
                    Fix: Robocopy error code can be minus as well, will raise an error now
                    Fix: Move Trash files only if first robocopy was successful, otherwise skip this step
                    New: PSDrive handling, assume it is always Z: and then do not cleanup
                    New: Support starting the script multiple times in parallel
   V 1.5 - 02.07.2019: Fix: Increased robocopy timeout from 1 to 60 seconds
                New: Check robocopy Exitcode
                New: Exclude .OST File from robocopy (Outlook Cache file)
                New: Added disk space check for userprofile mode
                New: Move all other User files such as desktop.ini into another folder which is not part of OneDrive Migration
                New: Changed logging
   V 1.4 - 01.07.2019: Fix: Cleanup added
   V 1.3 - 24.06.2019: New: Exclude Desktop.ini and $Recycle.Bin during robocopy
   V 1.2 - 21.06.2019: Added CSV Support for mass import
   V 1.1 - 19.06.2019: Included -Limit All in Get-SPOSite and handle multiple owners to determine OneDrive location
   V 1.0 - 18.06.2019: Created
#>
[CmdletBinding(DefaultParameterSetName='SingleUser',
    SupportsShouldProcess=$true)]
Param(
    #If used with switch UserProfileMode this will be the UserProfilesRootDirectory e.g. \\fileserver\users$
    [Parameter(Mandatory=$true,
    Position=0,
    ParameterSetName='SingleUser')]
    [Parameter(Mandatory=$true,
    Position=0,
    ParameterSetName='UserProfileRootDir')]
    [Parameter(Mandatory=$false,ParameterSetName='CSVFile')]
    $SourceDirectory,

    #Define the users UPN going to migrate (single user or an array of multiple users)
    [Parameter(Mandatory=$false,ParameterSetName='UserProfileRootDir')]
    [Parameter(Mandatory=$false,ParameterSetName='CSVFile')]
    [Parameter(Mandatory=$true,ParameterSetName='SingleUser')]
    [array]$Users,

    #Tenant URL e.g. https://contoso.sharepoint.com = contoso
    [Parameter(Mandatory=$true)]
    [string]$Tenant,

    #Support for Multi Factor Authentication
    [Parameter(Mandatory=$false)]
    [switch]$UseMFAAuthentication,

    #separate with : e.g. 'pst:exe'
    [Parameter(Mandatory=$false)]
    [string]$ExludeFileExtensions = 'pst' ,

    #If specified, we assume the root directory for user profiles is used, otherwise single user
    [Parameter(Mandatory=$true,
    Position=1,
    ParameterSetName='UserProfileRootDir')]
    [switch]$UsersProfileMode = $false ,

    [Parameter(Mandatory=$true,
    Position=2,
    ParameterSetName='SingleUser')]
    $DestinationDirectory,

    [Parameter(Mandatory=$false,
    Position=3,
    ParameterSetName='UserProfileRootDir')]
    $DestinationDirectoryPostFix = '_O4B',

    # Define custom storage account name
    [string]$CustomStorageAccountName,

    # Define custom storage account key
    [string]$CustomStorageAccountKey,

    # Define a CSV file to import (single column with UPN name, no header)
    [Parameter(Mandatory=$false,ParameterSetName='UserProfileRootDir')]
    [Parameter(Mandatory=$true,ParameterSetName='CSVFile')]
    [string]$CSVFilePath
)

#FUNCTIONS and MAIN
#region Logging and generic functions

function Write-Log
{
<#
.Synopsis
   Write-Log writes a message to a specified log file with the current time stamp.
.DESCRIPTION
   The Write-Log function is designed to add logging capability to other scripts.
   In addition to writing output and/or verbose you can write to a log file for
   later debugging.
.NOTES
   Created by: Jason Wasser @wasserja
   Modified by: Dennis Hobmaier
   Modified: 07/08/2019 09:30:19 AM  

   Changelog:
    * Code simplification and clarification - thanks to @juneb_get_help
    * Added documentation.
    * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks
    * Revised the Force switch to work as it should - thanks to @JeffHicks

   To Do:
    * Add error handling if trying to create a log file in a inaccessible location.
    * Add ability to write $Message to $Verbose or $Error pipelines to eliminate
      duplicates.
.PARAMETER Message
   Message is the content that you wish to add to the log file. 
.PARAMETER Path
   The path to the log file to which you would like to write. By default the function will 
   create the path and file if it does not exist. 
.PARAMETER Level
   Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
.PARAMETER NoClobber
   Use NoClobber if you do not wish to overwrite an existing file.
.EXAMPLE
   Write-Log -Message 'Log message' 
   Writes the message to c:\Logs\PowerShellLog.log.
.EXAMPLE
   Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
   Writes the content to the specified log file and creates the path and file specified. 
.EXAMPLE
   Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
   Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
.LINK
   https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path=$logfile,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",
        
        [Parameter(Mandatory=$false)]
        [switch]$NoClobber, 

        [Parameter(Mandatory=$false)]
        [Alias('LogErrorPath')]
        [string]$ErrorLogPath=$Errorfile
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            New-Item $Path -Force -ItemType File | Out-Null
            }

        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $ErrorLogPath) -AND $NoClobber) {
            Write-Error "Log file $ErrorLogPath already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $ErrorLogPath)) {
            Write-Verbose "Creating $ErrorLogPath."
            New-Item $ErrorLogPath -Force -ItemType File | Out-Null
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Host $Message
                $LevelText = 'INFO:'
                }
            }
        
        # Write log entry to $Path
        "$FormattedDate`t$LevelText`t$Message" | Out-File -FilePath $Path -Append
        If ($Level -eq 'Error')
        {
            #Add to error file
            "$FormattedDate`t$LevelText`t$Message" | Out-File -FilePath $ErrorLogPath -Append
        }
    }
    End
    {
    }
}

function Get-DiskSpace {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DiskName,

        [Parameter(Mandatory = $false)]
        [int64]$MinimumDiskSpaceInBytes = '102400000000' # 100 GB
    )
    #(Get-PSDrive -Name S).Free -gt 102400000000   
    If ((Get-PSDrive $DiskName).Free[0] -ge $MinimumDiskSpaceInBytes) {
        #More than 100 GB free
        return $true
    } else {
        #Less than 100 GB free
        return $false
    }
}
function Move-Files {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        $SourceDir,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        $DestDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $cmdRobocopyLog
    )
    #Move files
    Write-Verbose 'Entry Move-Files'
    $cmdRobocopyLog = """$cmdRobocopyLog"""
    $cmdRobocopy = Join-Path -Path $env:SystemRoot -ChildPath ('system32\robocopy.exe')
    $cmdRobocopy = $cmdRobocopy + ' ' +`
        """$SourceDir""" + ' ' +`
        """$DestDir""" + ' ' +`
        '/MOVE /E /R:0 /W:1 /XF *.pst /XF *.ost /XF Thumbs.db /XF Desktop.ini /XF *.pst.tmp /XD ''$Recycle.Bin'' /COPY:DATO /DCOPY:DAT /NP /V /UniLog:' + $cmdRobocopyLog
    Write-Log "Run cmd $cmdRobocopy"

    Invoke-Expression $cmdRobocopy -ErrorAction SilentlyContinue

    return $lastexitcode
    Write-Verbose 'Leave Move-Files'
}

function Move-NonO4BFiles {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        $SourceDir,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        $DestDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $cmdRobocopyLog
    )
    #Move files
    Write-Verbose 'Entry MoveNonO4B-Files'
    $cmdRobocopyLog = """$cmdRobocopyLog"""
    $cmdRobocopy = Join-Path -Path $env:SystemRoot -ChildPath ('system32\robocopy.exe')
    $cmdRobocopy = $cmdRobocopy + ' ' +`
        """$SourceDir""" + ' ' +`
        """$DestDir""" + ' ' +`
        '/MOVE /E /R:0 /W:1 /XF *.pst /XF *.pst.tmp /COPY:DATO /DCOPY:DAT /NP /V /UniLog:' + $cmdRobocopyLog
    Write-Log "Run cmd $cmdRobocopy"

    Invoke-Expression $cmdRobocopy -ErrorAction SilentlyContinue

    return $Lastexitcode
    Write-Verbose 'Leave MoveNonO4B-Files'
}

#######################################################
# MAIN section                                        #
#######################################################


#region Setup Logging
$date = Get-Date -Format "yyyyMMddHHmmss"
$logfile = (join-path -Path $PSScriptRoot -ChildPath ("OneDriveMigration_log_" + $date + ".txt"))
$Errorfile = (join-path -Path $PSScriptRoot -ChildPath ("OneDriveMigration_error_" + $date + ".txt"))
#endregion

Write-Log 'Importing modules'

Import-module MSOnline -ErrorAction Stop
Import-module Microsoft.Online.SharePoint.PowerShell -ErrorAction stop
Import-module $env:userprofile\Documents\WindowsPowerShell\Modules\Microsoft.SharePoint.MigrationTool.PowerShell\microsoft.sharepoint.migrationtool.powershell.psd1    

If ($UsersProfileMode)
{
    Write-Log 'Checking available storage on source'
    #Take care, there's a Bug in robocopy when moving files and storage has no free space
    # Then robocopy could create a 0 KB file and delete the source at the same time resulting in data loss!
    #New-PSDrive is different on share and local, so check
    If ($SourceDirectory.IndexOf(":\") -eq 1) {
        Write-Log 'Source is local disk'
        #Check if already there, assume we are using always Z so we support starting the script multiple times
        If (!(Get-PSDrive -Name 'Z' -ErrorAction SilentlyContinue))
        {
            New-PSDrive -Name 'Z' -PSProvider FileSystem -Root $SourceDirectory | Out-Null
        }
    } else {
        Write-Log 'Source is UNC Share'
        # This works for network drive
        If (!(Get-PSDrive -Name 'Z' -ErrorAction SilentlyContinue))
        {
            New-PSDrive -Name 'Z' -PSProvider FileSystem -Root $SourceDirectory -Persist | Out-Null
        }
    }
    If (!(Get-DiskSpace -DiskName 'Z')) {
        Write-Log 'Not enough disk space' -Level 'Error'
        break
    }
}


Write-Log "User Profile Mode $UsersProfileMode"
$StartTime = Get-Date
Write-Log 'Connecting, yes multiple times'
try {
    #Try authentication
    If ($UseMFAAuthentication) {
        Write-Log 'Connect to Msol'
        Connect-MsolService -ErrorAction Stop
        Write-Log 'Connect to SPO'
        Connect-SPOService -Url "https://$tenant-admin.sharepoint.com" -ErrorAction Stop
        
        Write-Log 'Connect to SPMT'
        #Register the SPMT session with SPO credentials#
        if ($CustomStorageAccountName.Length -gt 1) {
        Register-SPMTMigration -Force `
            -MigrateOneNoteFolderAsOneNoteNoteBook $true `
            -SkipFilesWithExtension $ExludeFileExtensions `
            -MigrateHiddenFiles $true `
            -MigrateFilesAndFoldersWithInvalidChars $true `
            -UseCustomAzureStorage $true `
            -CustomAzureAccessKey $CustomStorageAccountKey `
            -CustomAzureStorageAccount $CustomStorageAccountName `
            -ErrorAction Stop
        } else {
            # No custom Azure storage
            Register-SPMTMigration -Force `
            -MigrateOneNoteFolderAsOneNoteNoteBook $true `
            -SkipFilesWithExtension $ExludeFileExtensions `
            -MigrateHiddenFiles $true `
            -MigrateFilesAndFoldersWithInvalidChars $true `
            -ErrorAction Stop        
        }
    } else {
        $cred = Get-Credential
        Connect-MsolService -Credential $cred -ErrorAction Stop
        Connect-SPOService -Url "https://$tenant-admin.sharepoint.com" -Credential $cred -ErrorAction Stop
        
        #Register the SPMT session with SPO credentials#
        if ($CustomStorageAccountName.Length -gt 1) {
            Register-SPMTMigration -SPOCredential $cred -Force `
                -MigrateOneNoteFolderAsOneNoteNoteBook $true `
                -SkipFilesWithExtension $ExludeFileExtensions `
                -MigrateHiddenFiles $true `
                -MigrateFilesAndFoldersWithInvalidChars $true `
                -UseCustomAzureStorage $true `
                -CustomAzureAccessKey $CustomStorageAccountKey `
                -CustomAzureStorageAccount $CustomStorageAccountName `
                -ErrorAction Stop
            } else {
                # No custom Azure storage
                Register-SPMTMigration -SPOCredential $cred -Force `
                -MigrateOneNoteFolderAsOneNoteNoteBook $true `
                -SkipFilesWithExtension $ExludeFileExtensions `
                -MigrateHiddenFiles $true `
                -MigrateFilesAndFoldersWithInvalidChars $true `
                -ErrorAction Stop        
            }     
    }    
}
catch [Exception] {
    $ErrorMessage = $_.Exception.Message
    Write-Log $ErrorMessage -Level Error
    break
}


#If CSV file is provided instead of individual users, import it and assign it to Users variable
If ($PSBoundParameters.ContainsKey('CSVFilePath'))
{
    $Users = @()
    $CSVUsers = Import-Csv -Path $CSVFilePath -Header 'UPN'
    foreach ($CSVUser in $CSVUsers)
    {
        $Users += $CSVUser.UPN
    }
}

#Receive all SharePoint sites once and cache it
Write-Log 'Get all SharePoint sites'
$DestinationSPOSites = (get-sposite -IncludePersonalSite $true -Limit All)
Write-Log 'All SharePoint sites received and cached'

foreach ($User in $Users)
{
    #Get Users with SharePoint/OneDrive license
    Write-Log "Working on user $User"
    Write-Log 'Has user a SharePoint license?'
    $Licensed = $false
    foreach ($license in (Get-MsolUser -UserPrincipalName $User).licenses.servicestatus) {
        if (($license.ServicePlan.ServiceType -eq 'SharePoint') -and ($license.ProvisioningStatus -eq 'Success')) {
            #License found
            $Licensed = $true
        }
    }
    if ($Licensed) {
        Write-Log 'User has license'
        #Get Destination OneDrive URL
        foreach ($DestinationSPOSite in $DestinationSPOSites | Where-Object {($_.Owner -eq $User) -and ($_.Template -like 'SPSPERS#*')})
        {
            Write-Log 'OneDrive already created'
            $DestinationSPOSiteFoundUrl = $DestinationSPOSite.URL
        }
        if ($DestinationSPOSiteFoundUrl -lt 0)
        {
            Write-Log 'Create OneDrive'
            #PreProvision OneDrive
            Request-SPOPersonalSite -UserEmails $User
            #Creation takes some time around 90 seconds in my case
            Start-Sleep -Seconds 120
            Write-Log 'Create OneDrive done'
            #Now determine URL
            foreach ($DestinationSPOSite in $DestinationSPOSites | Where-Object {($_.Owner -eq $User) -and ($_.Template -like 'SPSPERS#*')})
            {
                Write-Log 'OneDrive found'
                $DestinationSPOSiteFoundUrl = $DestinationSPOSite.URL
            }
        }
        Write-Log "OneDrive URL $DestinationSPOSiteFoundUrl"

        #Determine if single directory or user profile root directory
        If ($UsersProfileMode)
        {
            #Take care, another folder level
            #Assume folder name is same as UPN prefix
            # $User.Substring(0,$User.indexof('@')) = User Prefix dennis@hobmaier.net => dennis
            If (!(Test-Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix))))
                { new-item -Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix)) -ItemType Directory | out-null}
            Write-Log ("Move files to " + (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix)))
            If (Test-Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@')))))) {                               
                If (Get-DiskSpace -DiskName Z)
                {
                    $MovedFilesExitCode = Move-Files -SourceDir (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))))) `
                        -DestDir (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix)) `
                        -cmdRobocopyLog (Join-path -path $PSScriptRoot -ChildPath ("OneDriveRobocopy_log_" + (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix) + $date + ".txt"))
                    Write-Log ("Robocopy exit code "+ $MovedFilesExitCode[$MovedFilesExitCode.Length-1])
                    [int]$MovedFilesExitCodeNumber = $MovedFilesExitCode[$MovedFilesExitCode.Length-1]
                    Write-Verbose $MovedFilesExitCode.Length
                    #For some reason I get an object instead of pure Exit Code, so it is an array
                    #in the last field, there's the exit code
                    Write-Verbose $MovedFilesExitCode[$MovedFilesExitCode.Length-1]
                    If (($MovedFilesExitCodeNumber -le 7) -and ($MovedFilesExitCodeNumber -ge 0))
                    {
                        #Create individual migration plans within the loop
                        Write-Log 'Add SPMT Task'
                        try {
                            Add-SPMTTask -FileShareSource (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix)) `
                            -TargetSiteUrl $DestinationSPOSiteFoundUrl `
                            -TargetList 'Documents'
                        }
                        catch [Exception] 
                        {
                            $ErrorMessage = $_.Exception.Message
                            Write-Log "Error: $ErrorMessage" -Level Error
                        }
                        #Now move trash such as Desktop.ini, ost... Just leave .pst files
                        If (Get-DiskSpace -DiskName Z)
                        {
                            If (!(Test-Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix + '_NotMigrated'))))
                            { new-item -Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix + '_NotMigrated')) -ItemType Directory | out-null}                    
                            #Check if still something in
                            If(Test-Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))))))
                            {
                                $MovedNonO4BFilesExitCode = Move-NonO4BFiles -SourceDir (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))))) `
                                    -DestDir (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix + '_NotMigrated')) `
                                    -cmdRobocopyLog (Join-path -path $PSScriptRoot -ChildPath ("OneDriveRobocopyNonO4B_log_" + (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix) + $date + ".txt"))
                                #Same here, Exit code is an array an in the last one, there's the code
                                Write-Log ("Robocopy exit code " + $MovedNonO4BFilesExitCode[$MovedNonO4BFilesExitCode.Length-1])
                                [int]$MovedNonO4BFilesExitCodeNumber = $MovedNonO4BFilesExitCode[$MovedNonO4BFilesExitCode.Length-1]
                                If (($MovedNonO4BFilesExitCodeNumber -le 7) -and ($MovedFilesExitCodeNumber -ge 0))
                                {
                                    Write-Log "Moved NonO4B files completed for $User"
                                } else {
                                    Write-Log "Critical robocopy error, skipping user $User" -Level Error
                                }
                            }
                        } else {
                            Write-Log "No Disk space, skipping user $User" -Level Error
                        }                 
                    } else {
                        <#
                        CRITICAL ERROR (robocopy definition)
                            0×08   8       Some files or directories could not be copied
                    (copy errors occurred and the retry limit was exceeded).
                    Check these errors further.

                        0×10  16       Serious error. Robocopy did not copy any files.
                                    Either a usage error or an error due to insufficient access privileges
                                    on the source or destination directories.
                        #>
                        Write-Log "Critical robocopy error, skipping user $User" -Level Error
                        Write-Log "Skipping Non4B robocopy for $User as well" -Level Error
                    }
                } else {
                    Write-Log "No Disk space, skipping user $User" -Level Error
                }

            } else {
                Write-Log "Source folder does not exist, skipping user $User" -Level Error
            }


        } else {
            #Just a single user directory (e.g. Pilot users)
            If (!(Test-Path $DestinationDirectory)) { new-item -Path $DestinationDirectory -ItemType Directory | Out-Null}
            Write-Log "Move files to $DestinationDirectory"
            $MovedFilesExitCode = Move-Files -SourceDir $SourceDirectory `
                                -DestDir $DestinationDirectory `
                                -cmdRobocopyLog (Join-path -path $PSScriptRoot -ChildPath ("OneDriveRobocopy_log_" + (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix) + $date + ".txt"))
            Write-Log ("Robocopy exit code " + $MovedFilesExitCode[$MovedFilesExitCode.Length-1])
            [int]$MovedFilesExitCodeNumber = $MovedFilesExitCode[$MovedFilesExitCode.Length-1]

            If ($MovedFilesExitCodeNumber -le 7) {
                #Create individual migration plans within the loop
                Add-SPMTTask -FileShareSource $DestinationDirectory `
                        -TargetSiteUrl $DestinationSPOSiteFoundUrl `
                        -TargetList 'Documents'
            } else {
                Write-Log "Critical robocopy error, skipping user $User" -Level Error
            }
        }
    } else {
        Write-Log "User has no license $User" -Level Error
    }    
    

}

Write-Log 'Start SPMT Migration - status in console'
#Start Migration in the console.
Start-SPMTMigration    

Write-Log 'Done'
$EndTime = Get-Date
$Duration = $EndTime.Subtract($StartTime)
Write-Log "Migration took $Duration"

#Cleanup
$DestinationSPOSites = $null
$CSVUsers = $null
Disconnect-SPOService
# Leave the drive to support starting the script multiple times
#Remove-PSDrive -Name Z