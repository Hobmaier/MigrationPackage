<#
.SYNOPSIS
    Starts PreScan for defined users
.DESCRIPTION
    Use it to do a pre-scan just before the migration    
    Requires Start-PreScan.ps1 and a CSV file containing the UPN. 
    Assumes part before the @ of the UPN matches the folder name to scan
.EXAMPLE
    .\Start-CSVPreScan.ps1 -CSVFilePath C:\temp\Users.csv -path C:\temp\users
.EXAMPLE
    Another example of how to use this cmdlet
.OUTPUTS
    Log files in the same directory
.NOTES
   Created by: Dennis Hobmaier

   Changelog
   V 1.0 - 12.07.2019: Initial

#>
param(

    # Define a CSV file to import (single column with UPN name, no header)
    [Parameter(Mandatory=$true)]
    [ValidateScript({Get-Content $_})]
    [string]$CSVFilePath,

    # Define the root path to scan (userprofile mode) that meants a subfolder matches the username
    # e.g. "\\server\users" will be passed an csv contain alans@contoso.com, this will scan for
    # \\server\users\alans and create a individual log file
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    $path
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
        if ($log.Name -eq $user)
        {
            Write-Host "Start PreScan for: $User"
            .\Start-PreScan.ps1 -Sourcefolder $log.fullname -log .\pre_$User.log
            Write-Host "Done"
        }
    }
}