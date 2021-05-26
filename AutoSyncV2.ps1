

$autoRerunMinutes = 0 #If set to 0, only runs at logon, else, runs every X minutes AND at logon, expect random delays of up to 5 minutes due to bandwidth, service availability, local resources etc. I strongly recommend 0 or >60 as input value to avoid being throttled
$visibleToUser = $False #if set to true, user will see 
$tenantId = "7bd08b0b-3395-4dc1-94bb-d0b2e56a497f" #you can use https://gitlab.com/Lieben/assortedFunctions/blob/master/get-tenantIdFromLogin.ps1 to get your tenant ID

#The following Sharepoint and/or Teams libraries will be automatically synced by your user's Onedrive
#title        ==> The display name, don't change this later or the folder will be synced twice
#syncUrl      ==> the ODOpen URL, get it with Edge or Chrome when clicking on the Sync button of your library. If this does not show an URL, use Internet Explorer
$listOfLibrariesToAutoMount = @(
    @{"siteTitle" = "TestCalendarTeams";"listTitle"="Documents";"syncUrl" = "tenantId=7bd08b0b%2D3395%2D4dc1%2D94bb%2Dd0b2e56a497f&siteId=%7B%7D&webId=%7B%7D&listId=%7B%7D&webUrl=https%3A%2F%2Fumass%2Esharepoint%2Ecom%2Fsites%2FTestCalendarTeams&version=1"}
)



$scriptPath = $PSCommandPath

#Wait until Onedrive client is running, and has been running for at least 3 seconds
while($true){
    try{
        $o4bProcessInfo = @(get-process -name "onedrive" -ErrorAction SilentlyContinue)[0]
        if($o4bProcessInfo -and (New-TimeSpan -Start $o4bProcessInfo.StartTime -End (Get-Date)).TotalSeconds -gt 3){
            Write-Output "Detected a running instance of Onedrive"
            break
        }else{
            Write-Output "Onedrive client not yet running..."
            Sleep -s 3
        }
    }catch{
        Write-Output "Onedrive client not yet running..."
    }
}

#wait until Onedrive has been configured properly (ie: linked to user's account)
$odAccount = $Null
$companyName = $Null
$userEmail = $Null
:accounts while($true){
    #check if the Accounts key exists (Onedrive creates this)
    try{
        if(Test-Path HKCU:\Software\Microsoft\OneDrive\Accounts){
            #look for a Business key with our configured tenant ID that is properly filled out
            foreach($account in @(Get-ChildItem HKCU:\Software\Microsoft\OneDrive\Accounts)){
                if($account.GetValue("Business") -eq 1 -and $account.GetValue("ConfiguredTenantId") -eq $tenantId){
                    Write-Output "Detected $($account.GetValue("UserName")), linked to tenant $($account.GetValue("DisplayName")) ($($tenantId))"
                    if(Test-Path $account.GetValue("UserFolder")){
                        $odAccount = $account
                        Write-Output "Folder located in $($odAccount.GetValue("UserFolder"))"
                        $companyName = $account.GetValue("DisplayName").Replace("/"," ")
                        $userEmail = $account.GetValue("UserEmail")
                        break accounts
                    }else{
                        Write-Output "But no user folder detected yet (UserFolder key is empty)"
                    }
                }
            }             
        }
    }catch{$Null}
    Write-Output "Onedrive not yet fully configured for this user..."
    Sleep -s 2
}

#now check for any sharepoint/teams libraries we have to link:
:libraries foreach($library in $listOfLibrariesToAutoMount){
    #First check if any non-OD4B libraries are configured already
    $compositeTitle = "$($library.siteTitle) - $($library.listTitle)"
    $expectedPath = "$($odAccount.Name)\Tenants\$companyName".Replace("HKEY_CURRENT_USER","HKCU:")
    if(Test-Path $expectedPath){
        #now check if the current library is already syncing
        foreach($value in (Get-Item $expectedPath -ErrorAction SilentlyContinue).GetValueNames()){
            if($value -like "*$compositeTitle"){
                Write-Output "$compositeTitle is already syncing, skipping :)"
                continue libraries
            }
        }
    }
    
    #no library is syncing yet, or at least not the one we want
    #first, delete any existing content (this can happen if the user has manually deleted the sync relationship
    if(test-path "$($Env:USERPROFILE)\$companyName\$compositeTitle"){
        Write-Output "User has removed sync relationship for $compositeTitle, removing existing content and recreating..."
        Remove-Item  "$($Env:USERPROFILE)\$companyName\$compositeTitle" -Force -Confirm:$False -Recurse
    }else{
        Write-Output "First time syncing $compositeTitle, creating link..."
    }

    #wait for it to start syncing
    $slept = 10
    while($true){
        if(Test-Path "$($Env:USERPROFILE)\$companyName\$compositeTitle"){
            Write-Output "Detected existence of $compositeTitle"
            break
        }else{
            Write-Output "Waiting for $compositeTitle to get connected..."
            if($slept % 10 -eq 0){    
                #send ODOPEN command
                Write-Output "Sending ODOpen command..."
                start "odopen://sync/?$($library.syncUrl)&userEmail=$([uri]::EscapeDataString($userEmail))&webtitle=$([uri]::EscapeDataString($library.siteTitle))&listTitle=$([uri]::EscapeDataString($library.listTitle))"
            }
            Sleep -s 1
            $slept += 1
        }
    }
}

#everything has been mounted, time to process Folder Redirections
foreach($redirection in $listOfFoldersToRedirect){
    #onedrive redirection vs SpO/Teams libraries
    if($redirection.targetLocation -eq "onedrive"){
        $targetPath = Join-Path -Path $odAccount.GetValue("UserFolder") -ChildPath $redirection.targetPath
    }else{
        $libraryInfo = $listOfLibrariesToAutoMount[$([Int]$redirection.targetLocation)]
        $compositeTitle = "$($libraryInfo.siteTitle) - $($libraryInfo.listTitle)"
        $targetPath = Join-Path -Path (Get-Item "$($Env:USERPROFILE)\$companyName\$compositeTitle").FullName -ChildPath $redirection.targetPath
    }
    Write-Output "Redirecting $($redirection.knownFolderInternalName) to $targetPath"
    try{
        Redirect-Folder -GetFolder $redirection.knownFolderInternalName -SetFolder $redirection.knownFolderInternalIdentifier -Target $targetPath -copyExistingFiles $redirection.copyExistingFiles -setEnvironmentVariable $redirection.setEnvironmentVariable
        Write-Output "Redirected $($redirection.knownFolderInternalName) to $targetPath"
    }catch{
        Write-Output "Failed to redirect $($redirection.knownFolderInternalName) to $targetPath"
    }
}

#all normal folder redirection is done, process symbolic links
foreach($symLink in $listOfOtherFoldersToRedirect){
    #onedrive redirection vs SpO/Teams libraries
    if($symLink.targetLocation -eq "onedrive"){
        $targetPath = Join-Path -Path $odAccount.GetValue("UserFolder") -ChildPath $symLink.targetPath   
    }else{
        $libraryInfo = $listOfLibrariesToAutoMount[$([Int]$symLink.targetLocation)]
        $compositeTitle = "$($libraryInfo.siteTitle) - $($libraryInfo.listTitle)"
        $targetPath = Join-Path -Path (Get-Item "$($Env:USERPROFILE)\$companyName\$compositeTitle").FullName -ChildPath $symLink.targetPath
    }
    Write-Output "Redirecting $($symLink.originalLocation) to $targetPath"
    try{
        Redirect-SpecialFolder -originalLocation $symLink.originalLocation -target $targetPath -hide $symLink.hide -copyExistingFiles $symLink.copyExistingFiles
        Write-Output "Redirected $($symLink.originalLocation) to $targetPath"
    }catch{
        Write-Output "Failed to redirect $($symLink.originalLocation) to $targetPath"
    }
}

Throw "Scrip completed"
