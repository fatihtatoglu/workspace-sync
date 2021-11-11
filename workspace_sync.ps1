################################################################################
# Fatih Tatoğlu - https://github.com/fatihtatoglu
################################################################################
# Instructions
# 1. Copy this file
# 2. Create data.ini file
# 3. Execute script
################################################################################
function Initialize-Config {
    # Reference: https://stackoverflow.com/a/43697842
    $configFile = "data.ini";

    $anonymous = "NoSection";
    $ini = @{};

    switch -regex -file $configFile {  
        "^\[(.+)\]$" {
            # Section    
            $section = $matches[1];  
            $ini[$section] = @{};  
            $CommentCount = 0;  
        }  

        "^(;.*)$" {
            # Comment    
            if (!($section)) {  
                $section = $anonymous;  
                $ini[$section] = @{};  
            }  
            $value = $matches[1]; 
            $CommentCount = $CommentCount + 1;  
            $name = "Comment" + $CommentCount;  
            $ini[$section][$name] = $value; 
        }   

        "(.+?)\s*=\s*(.*)" {
            # Key    
            if (!($section)) {  
                $section = $anonymous;  
                $ini[$section] = @{};  
            }  
            $name, $value = $matches[1..2];  
            $ini[$section][$name] = $value;  
        }  
    }
    
    return $ini;
}

function New-Folder {
    param (
        [Parameter(Mandatory)][string]$Path
    )

    $isTargetDirectoryExist = Test-Path -Path $Path
    if ($false -eq $isTargetDirectoryExist) {
        New-Item -Force -Path $Path -ItemType "directory" | Out-Null
    }
}

function Sync-Repository {
    param (
        [Parameter(Mandatory)][string]$SourceLocation,
        [Parameter(Mandatory)][string]$TargetDirectory,
        [Parameter(Mandatory)][Hashtable]$Credential,
        [string]$Group,
        [string]$Fetch = "no",
        [string]$Prune = "no",
        [string]$Compact = "no"
    )

    $username = $Credential.username
    $token = $Credential.token
    $repositoryUrl = $SourceLocation.Replace("https://", "https://${username}:${token}@")

    # Clear for GitHub
    if ($true -eq $SourceLocation.Contains("github.com")) {    
        $repositoryPath = $SourceLocation.Replace("https://github.com", "").Replace(".git", "").Replace($Group, "").Replace("//", "");
    }

    $isrepositoryPathExist = Test-Path -Path $repositoryPath
    if ($false -eq $isrepositoryPathExist) {
        Start-Process -FilePath "git" -ArgumentList "clone $repositoryUrl" -Wait -NoNewWindow
        return;
    }

    $currentLocation = Get-Location
    if ("yes" -eq $Fetch) {
        Set-Location -Path $repositoryPath
        Start-Process -FilePath "git" -ArgumentList "fetch" -Wait -NoNewWindow
        Set-Location -Path $currentLocation
    }

    if ("yes" -eq $Prune) {
        Set-Location -Path $repositoryPath
        Start-Process -FilePath "git" -ArgumentList "remote prune origin" -Wait -NoNewWindow
        Set-Location -Path $currentLocation
    }

    if ("yes" -eq $Compact) {
        Set-Location -Path $repositoryPath
        Start-Process -FilePath "git" -ArgumentList "gc" -Wait -NoNewWindow
        Set-Location -Path $currentLocation
    }
}

$config = Initialize-Config

Set-Location -Path $config.repository.path
for ($i = 0; $i -lt $config.repository.count; $i++) {

    $group = $config.repository["${i}"]
    New-Folder -Path $group
    Set-Location -Path $group

    $repository = $config[${group}]
    for ($j = 0; $j -lt $repository.count; $j++) {
        
        $sourceLocation = $repository["${j}"]
        
        Sync-Repository -SourceLocation $sourceLocation -TargetDirectory $group  -Credential $config.credential  -Group $group  -Fetch $config.action.fetch  -Prune $config.action.prune  -Compact $config.action.compact
    }

    Set-Location -Path $config.repository.path
}