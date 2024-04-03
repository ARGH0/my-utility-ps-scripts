$loggerFullPath = $PSScriptRoot + '\..\shared\Logger.ps1'
Import-Module $loggerFullPath

<#
.SYNOPSIS
    Creates a new branch

.DESCRIPTION
    This function creates a new branch

    .PARAMETER branchName
    Specifies the new branch name
    
    .PARAMETER checkoutPath
    Specifies the path where the repository can be found

    .PARAMETER referenceBranch
    Specifies the branch to create the branch from
#>

function New([string] $branchName, [string] $checkoutPath, [string] $referenceBranch) {
    Log "##[section] Creating new branch $branchName"

    Log "Checking branchName"

    if ($branchName -like '') {
        Log-Error "Variable [branchName] can't be empty."
    }

    if ($branchName -like 'master' -or $branchName -like 'main') {
        Log-Error "Variable [branchName] can't be master or main."        
    }

    Set-Location $checkoutPath

    git checkout $referenceBranch
    
    if (-not $?) {
        throw "Failed to checkout $referenceBranch. It could be that it does not exists on the current repository."
    }

    git pull
    git checkout -b $branchName

    if (-not $?) {
        throw "Failed to create a new branch $branchName."
    }
}

<#
.SYNOPSIS
    Creates a new commit

.DESCRIPTION
    This function commits all the changes with the given commitMessage

    .PARAMETER commitMessage
    Specifies the new branch name
    
    .PARAMETER checkoutPath
    Specifies the path where the repository can be found
#>

function Commit([string] $commitMessage, [string] $checkoutPath) {
    Log "##[section] Commiting changes in git"

    if ($commitMessage -like '') {
        Log-Error "Variable [commitMessage] can't be empty."
    }

    Set-Location $checkoutPath

    git add .
    git commit -m $commitMessage
}

<#
.SYNOPSIS
    Pushes the branch

.DESCRIPTION
    This function pushes the new branch

    .PARAMETER branchName
    Specifies the branchName to push

    .PARAMETER checkoutPath
    Specifies the path where the repository can be found    
#>
function Push([string] $branchName, [string] $checkoutPath) {
    Set-Location $checkoutPath
    git push -u origin $branchName
}