# Version 1.2
# Author: Dennis Hobmaier
# Author Twitter: @DHobmaier
# This script will just export a SharePoint library to prepare for migration
# It requires SharePoint Online PowerShell and Office Online Sign In PowerShell http://powershell.office.com

$spsourcesite = "https://portal.contoso.com/projects/Hardware"
$spsourcelib = 'SharePointOnPrem'
$spexport = '\\contoso-sql\migration\export' #Temp

Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

write-host 'New Package'
# Run this on SharePoint Server
$pkg = Export-spweb -Identity $spsourcesite -Path $spexport -NoFileCompression -ItemUrl $spsourcelib -verbose