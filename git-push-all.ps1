# git-push-all.ps1
# Checks if gitverse and github remotes exist, adds them if not, then pushes current branch to both

param(
    [switch]$Force,
    [switch]$Help
)

# Define remote configurations
$GITVERSE_NAME = "gitverse"
$GITVERSE_URL = "ssh://git@gitverse.ru:2222/anarchic/oleg-deming-protocol.git"
$GITHUB_NAME = "github"
$GITHUB_URL = "git@github.com:anarchic-pro/oleg-deming-protocol.git"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Show help if requested
if ($Help) {
    Write-Host @"
git-push-all.ps1 - Push current branch to gitverse and github remotes

USAGE:
    .\git-push-all.ps1 [-Force] [-Help]

OPTIONS:
    -Force    Skip confirmation prompts when updating remote URLs
    -Help     Show this help message

DESCRIPTION:
    This script checks if 'gitverse' and 'github' remotes exist in the current
    git repository. If they don't exist, it adds them with predefined URLs.
    Then it pushes the current branch to both remotes.

    Remote URLs:
    - gitverse: $GITVERSE_URL
    - github:   $GITHUB_URL
"@
    exit 0
}

# Set error action preference
$ErrorActionPreference = "Stop"

try {
    # Check if we're in a git repository
    $null = git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not in a git repository!"
        exit 1
    }

    # Get current branch name
    $currentBranch = git branch --show-current 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($currentBranch)) {
        Write-Error "Unable to determine current branch!"
        exit 1
    }

    Write-Status "Current branch: $currentBranch"

    # Function to check if remote exists
    function Test-RemoteExists {
        param([string]$RemoteName)
        try {
            $null = git remote get-url $RemoteName 2>$null
            return $LASTEXITCODE -eq 0
        }
        catch {
            return $false
        }
    }

    # Function to get remote URL
    function Get-RemoteUrl {
        param([string]$RemoteName)
        try {
            $url = git remote get-url $RemoteName 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $url.Trim()
            }
            return $null
        }
        catch {
            return $null
        }
    }

    # Function to add remote if it doesn't exist
    function Add-RemoteIfMissing {
        param(
            [string]$Name,
            [string]$Url
        )
        
        if (Test-RemoteExists $Name) {
            $existingUrl = Get-RemoteUrl $Name
            Write-Status "Remote '$Name' already exists with URL: $existingUrl"
            
            # Check if URL matches expected URL
            if ($existingUrl -ne $Url) {
                Write-Warning "Remote '$Name' URL differs from expected. Expected: $Url"
                
                if ($Force) {
                    $updateUrl = $true
                } else {
                    $response = Read-Host "Do you want to update the URL? (y/N)"
                    $updateUrl = $response -match "^[Yy]$"
                }
                
                if ($updateUrl) {
                    git remote set-url $Name $Url
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Updated remote '$Name' URL to: $Url"
                    } else {
                        Write-Error "Failed to update remote '$Name' URL"
                        return $false
                    }
                }
            }
        } else {
            Write-Status "Adding remote '$Name' with URL: $Url"
            git remote add $Name $Url
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Added remote '$Name'"
            } else {
                Write-Error "Failed to add remote '$Name'"
                return $false
            }
        }
        return $true
    }

    # Add remotes if they don't exist
    Write-Status "Checking and adding remotes..."
    $gitverseResult = Add-RemoteIfMissing $GITVERSE_NAME $GITVERSE_URL
    $githubResult = Add-RemoteIfMissing $GITHUB_NAME $GITHUB_URL

    if (-not $gitverseResult -or -not $githubResult) {
        Write-Error "Failed to configure remotes properly"
        exit 1
    }

    # Show all remotes
    Write-Status "Current remotes:"
    git remote -v
    Write-Host ""

    # Function to push to remote with error handling
    function Push-ToRemote {
        param(
            [string]$Remote,
            [string]$Branch
        )
        
        Write-Status "Pushing '$Branch' to '$Remote'..."
        
        try {
            git push $Remote $Branch
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Successfully pushed to '$Remote'"
                return $true
            } else {
                Write-Error "Failed to push to '$Remote' (exit code: $LASTEXITCODE)"
                return $false
            }
        }
        catch {
            Write-Error "Failed to push to '$Remote': $($_.Exception.Message)"
            return $false
        }
    }

    # Push to both remotes
    Write-Status "Starting push to all remotes..."
    Write-Host ""

    # Track success/failure
    $gitverseSuccess = Push-ToRemote $GITVERSE_NAME $currentBranch
    Write-Host ""
    $githubSuccess = Push-ToRemote $GITHUB_NAME $currentBranch
    Write-Host ""

    # Summary
    Write-Status "Push Summary:"
    if ($gitverseSuccess) {
        Write-Success "✓ gitverse: SUCCESS"
    } else {
        Write-Error "✗ gitverse: FAILED"
    }

    if ($githubSuccess) {
        Write-Success "✓ github: SUCCESS"
    } else {
        Write-Error "✗ github: FAILED"
    }

    # Exit with appropriate code
    if ($gitverseSuccess -and $githubSuccess) {
        Write-Success "All pushes completed successfully!"
        exit 0
    } elseif ($gitverseSuccess -or $githubSuccess) {
        Write-Warning "Some pushes failed, but at least one succeeded."
        exit 1
    } else {
        Write-Error "All pushes failed!"
        exit 2
    }
}
catch {
    Write-Error "An unexpected error occurred: $($_.Exception.Message)"
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 3
}