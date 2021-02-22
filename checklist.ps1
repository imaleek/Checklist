clear

Get-Content ".\settings.ini" | foreach-object -begin {$config=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $config.Add($k[0], $k[1]) } } -ErrorAction stop

filter ColorWord {
    param(
        [string] $word,
        [string] $color
    )
    $line = $_
    $index = $line.IndexOf($word, [System.StringComparison]::InvariantCultureIgnoreCase)
    while($index -ge 0){
        Write-Host $line.Substring(0,$index) -NoNewline
        Write-Host $line.Substring($index, $word.Length) -NoNewline -ForegroundColor $color
        $used = $word.Length + $index
        $remain = $line.Length - $used
        $line = $line.Substring($used, $remain)
        $index = $line.IndexOf($word, [System.StringComparison]::InvariantCultureIgnoreCase)
    }
    Write-Host $line
}


function log {
    param(
    [parameter(Mandatory=$true)][String]$msg
        )

        $errorlogfolder = $config.errorlogfolder
        
        if ( !( Test-Path -Path $errorlogfolder -PathType "Container" ) ) {
            
           # Write-Verbose "Create error log folder in: $errorlogfolder"
            New-Item -Path $errorlogfolder -ItemType "Container" -ErrorAction SilentlyContinue
        }

        $filename ="\Error_Log"
        $filedate =get-date -format "dd-MM-yyyy"
        $file = $errorlogfolder+$filename+$filedate+".txt"
        #$file
    Add-Content -Path $file $msg
}

for (;;){

    #remove-variable * -ErrorAction SilentlyContinue
    #get-variable -Exclude PWD, * Preference | Remove-Variable -EA SilentlyContinue
    Remove-Variable table, foundprocesses -ErrorAction SilentlyContinue


    #(get-culture).datetimeformat
    $hour = get-date -format "HH"

    if(($hour-ge 0) -and ($hour -le 12)){$session = "Morning"}elseif (($hour-ge 12) -and ($hour -le 16)){$session = "Afternoon"}else{$session = "Evening"}

    $date = get-date -Format "dddd, dd MMMM, yyyy HH:mm"  
    $date.hour
    Write-Host '            '$session 'Checklist ' $date
    Write-Host '  '
    $foundprocesses = @()

    $timestamp = Get-Date
    $count = 0
    $Running =    "Running"
    $NotRunning = "Not Running"
    $table =@()


    $servers = $config.Servers -split "," |ForEach{ $_}
    $noofservers = $servers.count


    while($count -ne $noofservers){

        $processes = $config.Get_Item("process$count") -split "," | ForEach{$_}
        $hostname = $servers[$count]
        

        foreach($process in $processes)
            {   try{
                $foundprocesses += get-process -ComputerName $servers[$count] -name $process -ErrorAction stop 
                }

                catch{
                $errormsg = $_.ToString()
                $exception = $_.Exception
                $stacktrace = $_.ScriptStackTrace
                $failingline = $_.InvocationInfo.Line
                $positionmsg = $_.InvocationInfo.PositionMessage
                $pscommandpath = $_.InvocationInfo.PSCommandPath
                $failinglinenumber = $_.InvocationInfo.ScriptLineNumber
                $scriptname = $_.InvocationInfo.ScriptName

                log " " 
                log "************************************************************************************************************"
                log "Error happend at time: $timestamp on computer: $hostname"
                log "Error message: $errormsg"
                log "Error exception: $exception" 
                log "Failing script: $scriptname"
                log "Failing at line number: $failinglinenumber"
                log "Failing at line: $failingline"
                log "Powershell command path: $pscommandpath"
                log "Position message: $positionmsg" 
                log "Stack trace: $stacktrace"
                log "------------------------------------------------------------------------------------------------------------"
             
        
                }
                       
            }
    

        #$foundprocesses

        $table += foreach($item in $foundprocesses)
            {
                    if ($processes -icontains $item.ProcessName)
                    {
                        new-object psobject -Property @{
                        Process = $Item.ProcessName
                        Status = $Running
                        Server = $servers[$count]
 
                        }
                     }        
         
             }

         $table += foreach ($Item in $processes)
              {
                    if ($foundprocesses.Name -inotcontains $Item)
                        {
                            new-object psobject -Property @{
                            Process = $Item
                            Status = $NotRunning
                            Server = $servers[$count]
 
                            }
                        }
               }

        
        Remove-Variable processes
        
        
        $count += 1
    }

    $table |format-table|Out-String|ColorWord -word $NotRunning -color Red


    $mintime = $config.WaitForTime

    $sectime = 60 * $mintime
    sleep $sectime

    clear
}
