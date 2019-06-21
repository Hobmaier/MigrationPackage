<#
.SYNOPSIS
    Migrate to Microsoft OneDrive using SPMT
.DESCRIPTION
    Use this script for personal Home folder to OneDrive Migration
.EXAMPLE
    .\Start-SPMTO4BMigration.ps1 -SourceDirectory c:\temp\alans -DestinationDirectory c:\temp\alans_test -UseMFAAuthentication -Users alans@avengers.hobi.ws -Tenant theavengers
.EXAMPLE
    .\Start-SPMTO4BMigration.ps1 -SourceDirectory c:\temp\users -UseMFAAuthentication -Users alans@avengers.hobi.ws -Tenant theavengers -UsersProfileMode
.NOTES
   Changelog
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
    $SourceDirectory,

    #Define the users UPN going to migrate
    [Parameter(Mandatory=$true)]
    $Users,

    #Tenant URL e.g. https://contoso.sharepoint.com = contoso
    [Parameter(Mandatory=$true)]
    [string]$Tenant,

    #Support for Multi Factor Authentication
    [Parameter(Mandatory=$false)]
    [switch]$UseMFAAuthentication,

    [Parameter(Mandatory = $false)]
    $log = (Join-Path -Path $PSScriptRoot -ChildPath 'Start-SPMTO4BMigration.log'),

    [Parameter(Mandatory=$false)]
    [string]$LogName = 'MovedFiles',

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
    [string]$CustomStorageAccountKey
)


Write-Host 'Importing modules'
Import-module MSOnline -ErrorAction Stop
Import-module Microsoft.Online.SharePoint.PowerShell -ErrorAction stop
Import-module $env:userprofile\Documents\WindowsPowerShell\Modules\Microsoft.SharePoint.MigrationTool.PowerShell\microsoft.sharepoint.migrationtool.powershell.psd1

Write-Verbose "Creating $log."
New-Item $log -Force -ItemType File | Out-Null

Write-Host 'User Profile Mode ' $UsersProfileMode
$StartTime = Get-Date

#FUNCTIONS and MAIN
function Move-Files {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        $SourceDir,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        $DestDir,

        $cmdRobocopyLog = (Join-Path -Path $PSScriptRoot -ChildPath ($LogName + '.log'))
    )
    #Move files
    Write-Verbose 'Entry Move-Files'
    $cmdRobocopyLog = """$cmdRobocopyLog"""
    $cmdRobocopy = Join-Path -Path $env:SystemRoot -ChildPath ('system32\robocopy.exe')
    $cmdRobocopy = $cmdRobocopy + ' ' +`
        """$SourceDir""" + ' ' +`
        """$DestDir""" + ' ' +`
        '/MOVE /E /R:5 /W:1 /XF *.pst /COPY:DATO /DCOPY:DAT /NP /UniLog:' + $cmdRobocopyLog
    Write-Host 'Run cmd' $cmdRobocopy

    Invoke-Expression $cmdRobocopy -ErrorAction SilentlyContinue
    Write-Verbose 'Leave Move-Files'
}

Write-Host 'Connecting, yes multiple times'
If ($UseMFAAuthentication) {
    Write-Host 'Connect to Msol'
    Connect-MsolService -ErrorAction Stop
    Write-Host 'Connect to SPO'
    Connect-SPOService -Url "https://$tenant-admin.sharepoint.com" -ErrorAction Stop
    
    Write-Host 'Connect to SPMT'
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

foreach ($User in $Users)
{
    #Get Users with SharePoint/OneDrive license
    Write-Host 'Working on user ' $User
    'Working on user ' + $User | Out-File -FilePath $log -Append
    Write-Host 'Has user a SharePoint license?'
    $Licensed = $false
    foreach ($license in (Get-MsolUser -UserPrincipalName $User).licenses.servicestatus) {
        if (($license.ServicePlan.ServiceType -eq 'SharePoint') -and ($license.ProvisioningStatus -eq 'Success')) {
            #License found
            $Licensed = $true
        }
    }
    if ($Licensed) {
        Write-Host 'User has license'
        #Get Destination OneDrive URL
        $DestinationSPOSites = (get-sposite -IncludePersonalSite $true -Limit All)
        foreach ($DestinationSPOSite in $DestinationSPOSites | Where-Object {($_.Owner -eq $User) -and ($_.Template -like 'SPSPERS#*')})
        {
            Write-Host 'OneDrive already created'
            $DestinationSPOSiteFoundUrl = $DestinationSPOSite.URL
        }
        if ($DestinationSPOSiteFoundUrl -lt 0)
        {
            write-host 'Create OneDrive'
            #PreProvision OneDrive
            Request-SPOPersonalSite -UserEmails $User
            Start-Sleep -Seconds 5
            Write-Host 'Create OneDrive done'
            #Now determine URL
            foreach ($DestinationSPOSite in $DestinationSPOSites | Where-Object {($_.Owner -eq $User) -and ($_.Template -like 'SPSPERS#*')})
            {
                Write-Host 'OneDrive found'
                $DestinationSPOSiteFoundUrl = $DestinationSPOSite.URL
            }
        }
        Write-Host 'OneDrive URL ' $DestinationSPOSiteFoundUrl

        #Determine if single directory or user profile root directory
        If ($UsersProfileMode)
        {
            #Take care, another folder level
            #Assume folder name is same as UPN prefix
            # $User.Substring(0,$User.indexof('@')) = User Prefix dennis@hobmaier.net => dennis
            If (!(Test-Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix))))
                { new-item -Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix)) -ItemType Directory | out-null}
            Write-Host 'Move files to' (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix))
            If (Test-Path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@')))))) {
                Move-Files -SourceDir (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))))) `
                    -DestDir (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix)) `
                    -cmdRobocopyLog (Join-Path -path (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix)) -ChildPath '_MigrationRobocopy.log' )
                #Create individual migration plans within the loop
                Add-SPMTTask -FileShareSource (Join-Path -path $SourceDirectory -ChildPath (($User.Substring(0,$User.indexof('@'))) + $DestinationDirectoryPostFix)) `
                    -TargetSiteUrl $DestinationSPOSiteFoundUrl `
                    -TargetList 'Documents'
            } else {
                Write-Host 'Source folder doesn`t exist, skipping user ' $User
                'Source folder doesn`t exist, skipping user ' + $User | out-file -FilePath $log -Append
            }


        } else {
            #Just a single user directory (e.g. Pilot users)
            If (!(Test-Path $DestinationDirectory)) { new-item -Path $DestinationDirectory -ItemType Directory | Out-Null}
            Write-Host 'Move files to' $DestinationDirectory
            Move-Files -SourceDir $SourceDirectory -DestDir $DestinationDirectory
            #Create individual migration plans within the loop
            Add-SPMTTask -FileShareSource $DestinationDirectory `
                    -TargetSiteUrl $DestinationSPOSiteFoundUrl `
                    -TargetList 'Documents'

        }
    } else {
        Write-Host 'User has no license' $User -ForegroundColor Red
        'User has no license ' + $User | Out-File -FilePath $log -Append
    }    
    

}

#Start Migration in the console.
Start-SPMTMigration

Write-Host 'Done'
$EndTime = Get-Date
Write-Host 'Migration took ' $EndTime.Subtract($StartTime)
'Migration took ' + $EndTime.Subtract($StartTime) | out-file -FilePath $log -Append