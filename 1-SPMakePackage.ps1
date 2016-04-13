Add-PSSnapin Microsoft.SharePoint.PowerShell
  $spsourcefilepath =   “\\v-sp-2013\Migration\ExportSP\Export”
$sppackageoutputpath = “\\v-sp-2013\Migration\SPPackage”
$sppackageoutputpathout = “\\v-sp-2013\Migration\SPOutputPackage”
$sptargetweburl = “https://s2sshowcase.sharepoint.com/sites/Dennis/Office365Konf/”
$sptargetdoclib = "Freigegebene%20Dokumente"
#$sptargetsubfolder = "Office365Konferenz"
  $spfilecontainername = "sppayload"
  $sppackagecontainername = "spmigrationpackage"
  $spazurequeuename = “spspomigration”
  $spazureaccountname = "hobiblob"
  $spazurestoragekey ="1GXSdrSrMQtQ+mlUyY/ZYa/f8yx8ex16mXtEJA8VeEdYFAnk8mzyFVkU4B57szdLuBH/DdQ04N7Y3RgP9A5+hw=="
Export-spweb -Identity "http://v-sp-2013/sites/1_Marketing/Office365Konf" -Path \\v-sp-2013\Migration\ExportSP\Export -NoFileCompression -ItemUrl "Shared%20Documents"