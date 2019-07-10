<#
.SYNOPSIS
    Moves Log files
.DESCRIPTION
    Move Log files based on usernames. Idea is to use in conjunction with Start-PreScan.ps1
.EXAMPLE
    Move-Log -path "C:\Migration\prescan" -destinationpath "C:\Migration\PreScan\Batch3" -CSVFilePath "C:\Migration\batch3Users.csv"
.EXAMPLE
    Another example of how to use this cmdlet

.NOTES
    Author: Dennis Hobmaier    
    V 1.0 - 10.07.2019: New
#>

[CmdletBinding()]

Param (
    # Source were all logs are
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    $path,

    # Destinationpath were logs from specified users should go to
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    $destinationpath,

    # Define a CSV file to import (single column with UPN name, no header)
    [Parameter(Mandatory=$true)]
    [ValidateScript({Get-Content $_})]
    [string]$CSVFilePath
)
    
If ($PSBoundParameters.ContainsKey('CSVFilePath'))
{
    Write-Host 'Importing CSV'
    $Users = @()
    $CSVUsers = Import-Csv -Path $CSVFilePath -Header 'UPN'
    foreach ($CSVUser in $CSVUsers)
    {
        #Assume we have the UPN in the CSV file, extract that
        $UserPrefix = $CSVUser.UPN.Split('@')
        #Prefix always in 0
        $Users += $UserPrefix[0]
    }
}

Write-Host 'Get Directory'
$logs = Get-ChildItem -Path $path

foreach ($log in $logs) 
{
    Write-Host "Working on $($log.name)"
    foreach ($user in $Users)
    {
        if ($log.Name -eq "pre_$user.log")
        {
            Write-Host 'Move log'
            Move-Item $log.fullname -Destination $destinationpath
        }
    }
}

Write-Host 'Create summary file'
#Create summary log
#Get Base name of CSV first
$summaryfilename = $CSVFilePath.Substring(($CSVFilePath.LastIndexOf('\') +1),($CSVFilePath.Length - $CSVFilePath.LastIndexOf('\')-1))
$summaryfilename = $summaryfilename.Split('.')
Get-ChildItem -Path $destinationpath | Get-Content | Out-File .\"_PreScanSummary_$($summaryfilename[0]).csv"
Move-Item .\"_PreScanSummary_$($summaryfilename[0]).csv" -Destination $destinationpath
Write-Host 'Done'