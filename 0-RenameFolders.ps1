$path = "\\v-sp-2013\Demodata"
$folders = Get-ChildItem $path -Directory
foreach($folder in $folders)
{
    
    $SpaceLocation = $folder.Name.IndexOf(" ")
    $ShortName = $folder.Name.Substring(0,$SpaceLocation)
    Rename-Item -Path $folder.Name -NewName $ShortName
}