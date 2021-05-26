# William Farland
# 5/25/2021
# Things to keep in mind:
# Need to be a SharePoint owner on the site to return information w/o errors

# ** Vars that should not change based on SharePoint Site
# Tenant Name, Same for all UMass SharePoint sites
$tenant = 'umass' 
# Tenant ID, Pretty sure its same for all UMass SharePoint sites
$tenantId = '7bd08b0b-3395-4dc1-94bb-d0b2e56a497f' 

# *** Vars that can change depending on SharePoint Site ***
$siteName = 'TestCalendarTeams' #Sharepoint site name
$docLib = 'Documents' #Sharepoint Document Library

# Get Connection - Use @umass.edu in username when promt appears
$cred = Get-Credential 
Connect-PnPOnline https://$tenant.sharepoint.com/sites/$siteName -SPOManagementShell

# Conversion(s)
$tenantId = $tenantId -replace '-','%2D'
$PnPSite = Get-PnPSite -Includes Id | select id
$PnPSite = $PnPSite.Id -replace '-','%2D'
$PnPSite = '%7B' + $PnPSite + '%7D'
$PnPWeb = Get-PnPWeb -Includes Id | select id
$PnPWeb = $PnPWeb.Id -replace '-','%2D'
$PnPWeb = '%7B' + $PnPWeb + '%7D'
$PnPList = Get-PnPList $docLib -Includes Id | select id
$PnPList = $PnPList.Id -replace '-','%2D'
$PnPList = '%7B' + $PnPList + '%7D'
$PnPList = $PnPList.toUpper()

# Put it all together into FULLURL var
$FULLURL = 'tenantId=' + $tenantId + '&siteId=' + $PnPSite + '&webId=' + $PnPWeb + '&listId=' + $PnPList + '&webUrl=https%3A%2F%2F' + $tenant + '%2Esharepoint%2Ecom%2Fsites%2F' + $siteName + '&version=1'

# Print FULLURL to console - viola
Write-Output $FULLURL