<#
.Synopsis
   Start-PreScan.ps1 will scan a fileshare for specific characters and folders
.DESCRIPTION
   This primary goal is to identify files and folder which aren't supported by SharePoint Online and
   OneDrive for Business. Use this script to prepare your migration phase.
.NOTES
   Created by: Dennis Hobmaier

   Currently we don't check for 400 characters limitation as on filesystem we 
   trust there will be a problem with 256 already.

   Changelog
   V 1.6 - 10.07.2019: New: Added cmdletbinding
   V 1.5 - 02.07.2019:
            New: Added .ost to InvalidExtensions
            New: Scan for Thumbs.db
   V 1.4 - 28.06.2019:
            Fix: Updated OneNote scan value from 10 to 100 MB
   V 1.3 - 27.06.2019: 
            New: Scan for Recycle Bin and hidden files
   V 1.2 - 27.06.2019: 
            New: Added OneNote scan for large Notebooks 
            New: Scan for blank at the end of a folder e.g. "foldername "
            Fix: Added error handling (Access denied, long folder path) and do not create an error in CLI
   V 1.1 - 07.06.2019: Added to logic to scan for root folders also one level deep (use case scanning
                        all users homeshare root directory)
   V 1.0 - 06.06.2019: Created

.PARAMETER Sourcefolder
   Provide a local folder or share you would like to scan.
   
.PARAMETER log
   Provide a path including a filename to the logfile. By default same directory than the script.

.EXAMPLE
   Start-PreScan.ps1 -Sourcefolder c:\temp
   This will scan the folder and all it's subfolders and items. Log will be created in scripts directory.

.EXAMPLE
   Start-PreScan.ps1 -Sourcefolder c:\temp -log c:\mylog.log
   This will scan the folder and all it's subfolder and items. Log will be created here c:\mylog.log

.EXAMPLE
   gci C:\temp\users | foreach { .\Start-PreScan.ps1 -Sourcefolder $_.fullname -log ".\pre_$($_.Name).log" }
   This uses pipe and creates a new log file for each subfolder (when it is a users homedirectory).
.LINK
   https://support.office.com/en-us/article/Invalid-file-names-and-file-types-in-OneDrive-OneDrive-for-Business-and-SharePoint-64883a5d-228e-48f5-b3d2-eb39e07630fa#invalidcharacters
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_})]
    $Sourcefolder = 'C:\Temp\source',
    [Parameter(Mandatory = $false)]
    $log = (Join-Path -Path $PSScriptRoot -ChildPath 'Start-PreScan.log')
)

#Make sure no errors are logged before running the script
$Error.Clear()

$searchstrings = @(
    '~'
    '_vti_'
)

<# Invalid for NTFS filesystem as well
   '\'
     '`?' 
   '`*'
    ':' 
    '<' 
    '>' 
    '/'
    '"'
    '|'
#>
$InvalidExtensions = @(
    '.pst'
    '.ost'
)
$InvalidNames = @(
    '.lock'
    'CON'
    'PRN'
    'AUX'
    'NUL'
    'COM1'
    'COM2'
    'COM3'
    'COM4'
    'COM5'
    'COM6'
    'COM7'
    'COM8'
    'COM9'
    'LPT1'
    'LPT2'
    'LPT3'
    'LPT4'
    'LPT5'
    'LPT6'
    'LPT7'
    'LPT8'
    'LPT9'
    'desktop.ini'
    '$Recycle.Bin'
    'Thumbs.db'
)
$InvalidRootFolders = @(
    'Forms'
)
# Create large dummy cmd: fsutil file createnew largefile15GB.pst 16106127360
$MaxFileSize = '16106127360' # 15 GB max file size in OneDrive
$WarningOneNoteFileSize = '102400000' # Larger than 100 MB

Write-Verbose "Creating $log."
New-Item $log -Force -ItemType File | Out-Null

# NFR11: Scan also one level depth
# Example folder \\server\usershares$ will be scanned
# But \\server\usershares$\dennis\forms is prohibited in SharePoint and wouldn't be recognized without this
Get-ChildItem -path $Sourcefolder -Directory -Recurse -Depth 1 -Attributes normal,directory,system,hidden,archive,readonly -ErrorAction SilentlyContinue | ForEach-Object {
    foreach ($InvalidRootFolder in $InvalidRootFolders) {
        if ($_.Name.ToLower() -eq $InvalidRootFolder.ToLower()) {
            Write-Output "Invalid root folder $($_.FullName)"
            'Invalid root folder,'+$InvalidRootFolder+','+$_.FullName | Out-File $log -Append
        }
    }     
}


Get-ChildItem -path $Sourcefolder -Recurse -Attributes normal,directory,system,hidden,archive,readonly -ErrorAction SilentlyContinue | ForEach-Object {
    foreach ($searchstring in $searchstrings) {
        if ($_.Name -match "$searchstring") {
            Write-Host 'Invalid character ' $_.FullName
            'Invalid character,'+$searchstring+','+$_.FullName | Out-File $log -Append
        }
    }    
    foreach ($InvalidExtension in $InvalidExtensions) {
        if ($_.Extension -eq $InvalidExtension) {
            Write-Host 'Invalid extension' $_.FullName
            'Invalid extension,'+$InvalidExtension+','+$_.FullName | Out-File $log -Append
        }
    }  
    foreach ($InvalidName in $InvalidNames) {
        if ($_.Name -eq $InvalidName) {
            Write-Host 'Invalid name' $_.FullName
            'Invalid name,'+$InvalidName+','+$_.FullName | Out-File $log -Append
        }
    }         
    if ($_.Name.EndsWith(" ")) {
        Write-Host 'Space at the end ' $_.FullName
        'Space at the end,space,'+$_.FullName | Out-File $log -Append        
    }

    if ($_.Length -ge $MaxFileSize) {
        Write-Host 'Large File found ' $_.FullName
        'Large File found,'+$_.Length+','+$_.FullName | Out-File $log -Append
    }
    #Check for large OneNote Files and generate Warning
    if (($_.Length -ge $WarningOneNoteFileSize) -and ($_.Extension -eq '.one') )
    {
        Write-Host 'Large OneNote found ' $_.FullName
        'Large OneNote found,'+$_.Length+','+$_.FullName | Out-File $log -Append
    }
}

#Now collect all errors
foreach ($ErrorDetail in $Error) {
    Write-Host 'ERROR ' $ErrorDetail.exception
    'ERROR,AccessError,'+$ErrorDetail.TargetObject | Out-File $log -Append
}
