$loggerFullPath = $PSScriptRoot + '\..\Environment scripts\Logger.ps1'
Import-Module $loggerFullPath

<#
.SYNOPSIS
    Replaces the content of the given files

.DESCRIPTION
    This function replaces the contents of the given file

.PARAMETER path
    Specifies the path to search for
.PARAMETER filter
    Specifies the filter
.PARAMETER oldText
    Specifies the text to find
.PARAMETER newText
    Specifies the new text  
.PARAMETER includeChildFolders
    Specifies if the child directories should be included.
#>

function ReplaceContents([string] $path, [string] $filter, [string] $oldText, [string] $newText, [bool] $includeChildFolders) {

    if ($includeChildFolders)
    {
        $folders = Get-ChildItem $path $filter -Recurse;
    }
    else
    {
        $folders = Get-ChildItem $path $filter;
    }

    $folders  |
    Foreach-Object {
        Log "Replacing contents in file $($_.FullName)"
        (Get-Content -Raw $_.FullName) -replace $oldText, $newText | Set-Content -NoNewline $_.FullName -Encoding UTF8      
    }
}