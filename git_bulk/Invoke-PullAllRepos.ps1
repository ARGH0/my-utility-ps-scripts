param([string]$checkoutBranch = "master")
function Invoke-PullAllRepos ([string]$checkoutBranch = "master")
{
    Get-ChildItem -Recurse -Depth 2 -Force |
    Where-Object { $_.Mode -match "h" -and $_.FullName -like "*\.git" } |
    ForEach-Object {
        $dir = Get-Item (Join-Path $_.FullName "../")
        Push-Location $dir
        if ($checkoutBranch) {
            $branch= &git rev-parse --abbrev-ref HEAD
            if ($branch -ne $checkoutBranch) {
                "Checkout out $($checkoutBranch) branch for $($dir.Name)"
                git checkout $checkoutBranch
            }
        }
        "Pulling $($dir.Name)"
        git pull -p
        Pop-Location
    }
}
Invoke-PullAllRepos