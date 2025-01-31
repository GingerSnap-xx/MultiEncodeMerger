function Find-MultiEncodedFiles {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [String]
        $path,
        [Parameter(Mandatory=$true)]
        [string]
        $extensionToKeep,
        [switch]
        $recurse,
        [switch]
        $delete
    )
    $startDir = $PWD
    try{
       
        $output = @{}
    _searcher -path $path -extensionToKeep $extensionToKeep -outputCollection $output -recurse:$recurse
    

    if($delete){
        Write-Verbose "Delete flag passed, going to clean up now."
        
            $output.GetEnumerator() | ForEach-Object {
                $root = $_

                  
                    if($root.Value.ToDelete.Length -gt 0){
                    Write-Verbose "Processing $($root.Key)"
                    Write-Verbose "$($root.Value)"
                    $root.Value.ToDelete?.GetEnumerator() | ForEach-Object{
                        if ($PSCmdlet.ShouldProcess($_, "Deleting because flac file exists: $($root.Value.ToKeep.FullName)")) {
                            Write-Verbose "this is where I would have deleted something."
                        }
                    }
                }
                
            }
            
    }
    else{
        Write-Verbose "Delete flag off. Outputting only"
    }
    return $output
    }
    finally{
        #if there is an error or they kill the script mid way through, return them to their starting location.
        Set-Location $startDir
    }
}
function _searcher {
    [CmdletBinding()]
    param (
        [String]
        $path,
        [Parameter(Mandatory=$true)]
        [string]
        $extensionToKeep,
        [switch]
        $recurse,
        [hashtable]
        $outputCollection
    )
    

    #Write-Verbose "Starting"
    if($null -eq $path){
        $path = (Get-Item .).FullName
    }

    Push-Location $path
    #filter to only the target file extension and, if recurse is set, child directories.
    # its simpler to skip the unmatched files by first looking for our target extension to keep.
    #if a file doesn't exist with the extension, we should leave alone the duplicates
    #it might be helpful in the future to still process everything and report on files that don't have a match but trying to keep it simple now.
    Get-ChildItem | Where-Object {$_.Extension -eq $extensionToKeep -or ($_.PSIsContainer -and $recurse)} | ForEach-Object {
        if($_.PSIsContainer -and $recurse){
            #recurse
            #Write-Verbose "Recursing into container $_"
            _searcher -path $_.FullName -extensionToKeep $extensionToKeep -outputCollection $outputCollection -recurse
        }
        else{
            #Write-Verbose "Handling $($_.Name)"
            
            $base_name = $_.BaseName
            $existing = $outputCollection[$base_name] 
          
            if($null -eq $existing){
                $existing = @{"ToKeep"=$_; "ToDelete"=@()};
                $outputCollection["$($_.BaseName)"] = $existing 
                
            }
            else{
                Write-Warning "Multiple copies of $($_.BaseName) found with extension to keep!!! 
                Original: $($existing.ToKeep.FullName)
                "
                Get-ChildItem | Where-Object {$_.BaseName -eq $base_name -and $_.Extension -eq $extensionToKeep } | ForEach-Object {Write-Warning $_.FullName}
            }
            #now that we have a handle on the "good" file, lets search for duplicates with other extensions.
            $extras = Get-ChildItem | Where-Object {$_.BaseName -eq $base_name -and $_.Extension -ne $extensionToKeep -and !$_.PSIsContainer}
            $existing.ToDelete += $extras
            
        }
    }


    Pop-Location
}

Export-ModuleMember -Function Find-MultiEncodedFiles