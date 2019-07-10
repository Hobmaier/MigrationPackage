# MigrationPackage
Code example on how to Use SPOMigrationPackage to migrate filesystem or SharePoint on-prem into SharePoint Online

For demo purpose Scripts are splittet and are intended to run with PowerShell ISE, names like 1_* 2_*...

I've recently added Start-SPOMigration.ps1 which contains all steps ready to go for using fileshare as a source. Please take care, that there are slight differences when using SharePoint on-prem as a source.

# Start-PreScan
To run it use the following command for help: Get-help .\Start-Prescan.ps1
 
Run the following command and specify two parameters:
-	Sourcefolder: the folder to scan (e.g. c:\files\usersprofiles or \\server\userprofiles$
-	Log: A complete path to a logfile which will be created, e.g. c:\temp\sourcefolder.log
PS C:\Users\dhobmaie\OneDrive - Hobi\Consulting\SharePoint\HighSpeedMigration\MigrationPackage> .\Start-PreScan.ps1 -Sourcefolder c:\temp\source -log c:\temp\sourcefolder.log
 
Log is a “,” delimited filed – so you could rename it to CSV and open it with Excel to filter better on it:
 
# Move-Log
Small tool to support moving log files created by Start-PreScan (to separate them for each user). Ideally in conjuction when doing mass migration from home dir to OneDrive

# Start-SPMTO4BMigration
To run it use the following command for help: Get-help .\Start-SPMTO4BMigration.ps1

This will use robocopy and SPMT (SharePoint Migration Toolkit) to move files from A to B and upload it into
users OneDrive.
It's perfectly made for fileshare where all user home dir's are located to do mass migration.