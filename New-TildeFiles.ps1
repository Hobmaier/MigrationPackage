while ($i -le 500)
{
    "Hello" | Out-File "C:\temp\source\test~$i.txt"
    $i++
}