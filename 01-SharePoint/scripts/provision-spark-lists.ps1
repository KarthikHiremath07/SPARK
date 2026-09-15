<#
.SYNOPSIS
    Provisions the SPARK_Opportunities and SPARK_Applications lists (Phase 1 schema)
    on a SharePoint Online Communication Site.

.DESCRIPTION
    Requires the PnP.PowerShell module:
        Install-Module PnP.PowerShell -Scope CurrentUser

    Run against the target site with an account that has at least Site Owner rights:
        .\provision-spark-lists.ps1 -SiteUrl "https://<tenant>.sharepoint.com/sites/SPARK"

    The script is idempotent for list creation (skips if a list with the same
    name already exists) but will attempt to (re)add fields each run, so re-running
    on a partially-provisioned site is safe to retry after fixing an error.

.NOTES
    Tested against PnP.PowerShell cmdlet syntax current as of the 2.x module line.
    This script has not been executed against a live tenant by the assistant —
    review the parameters (choice values, field names) against your tenant
    before running in production, and consider a test site collection first.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl
)

$ErrorActionPreference = "Stop"

Import-Module PnP.PowerShell -ErrorAction Stop

Write-Host "Connecting to $SiteUrl ..." -ForegroundColor Cyan
Connect-PnPOnline -Url $SiteUrl -Interactive

# ============================================================
# LIST 1: SPARK_Opportunities
# ============================================================
$oppListName = "SPARK_Opportunities"

if (-not (Get-PnPList -Identity $oppListName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating list: $oppListName" -ForegroundColor Yellow
    New-PnPList -Title $oppListName -Template GenericList -OnQuickLaunch | Out-Null
}
else {
    Write-Host "$oppListName already exists - skipping creation" -ForegroundColor Green
}

Write-Host "Adding fields to $oppListName ..." -ForegroundColor Yellow

Add-PnPField -List $oppListName -DisplayName "Domain" -InternalName "Domain" `
    -Type Choice -Choices "AI/ML", "Cloud", "Data", "Frontend", "Backend", "DevOps", "Design" `
    -AddToDefaultView -Required

Add-PnPField -List $oppListName -DisplayName "Required Skills" -InternalName "RequiredSkills" `
    -Type Text -AddToDefaultView -Required

Add-PnPField -List $oppListName -DisplayName "Tech Stack" -InternalName "TechStack" `
    -Type Text -AddToDefaultView

Add-PnPField -List $oppListName -DisplayName "Openings" -InternalName "Openings" `
    -Type Number -AddToDefaultView

Add-PnPField -List $oppListName -DisplayName "Mentor Name" -InternalName "MentorName" `
    -Type User -AddToDefaultView

Add-PnPField -List $oppListName -DisplayName "Status" -InternalName "Status" `
    -Type Choice -Choices "Open", "Under Review", "Closed" `
    -AddToDefaultView -Required

# Default values
Set-PnPField -List $oppListName -Identity "Openings" -Values @{ DefaultValue = "1" }
Set-PnPField -List $oppListName -Identity "Status" -Values @{ DefaultValue = "Open" }

# Indexing (Status and Domain are filtered on in views / the list web part)
Set-PnPField -List $oppListName -Identity "Status" -Values @{ Indexed = $true }
Set-PnPField -List $oppListName -Identity "Domain" -Values @{ Indexed = $true }

# Marketplace-facing view: Open items only, newest first
if (-not (Get-PnPView -List $oppListName -Identity "SPARK_Active_Opportunities" -ErrorAction SilentlyContinue)) {
    Add-PnPView -List $oppListName -Title "SPARK_Active_Opportunities" `
        -Fields "Title", "Domain", "RequiredSkills", "TechStack", "Openings", "MentorName", "Status" `
        -Query "<Where><Eq><FieldRef Name='Status'/><Value Type='Choice'>Open</Value></Eq></Where><OrderBy><FieldRef Name='Created' Ascending='FALSE'/></OrderBy>"
    Write-Host "Created view SPARK_Active_Opportunities" -ForegroundColor Green
}

Write-Host "$oppListName provisioned." -ForegroundColor Green

# ============================================================
# LIST 2: SPARK_Applications
# ============================================================
$appListName = "SPARK_Applications"

if (-not (Get-PnPList -Identity $appListName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating list: $appListName" -ForegroundColor Yellow
    New-PnPList -Title $appListName -Template GenericList -OnQuickLaunch | Out-Null
}
else {
    Write-Host "$appListName already exists - skipping creation" -ForegroundColor Green
}

Write-Host "Adding fields to $appListName ..." -ForegroundColor Yellow

Add-PnPField -List $appListName -DisplayName "Employee ID" -InternalName "EmployeeID" `
    -Type Text -AddToDefaultView -Required

# Lookup to SPARK_Opportunities.Title - requires the opportunities list to exist first
$oppList = Get-PnPList -Identity $oppListName
$lookupFieldXml = "<Field Type='Lookup' DisplayName='Opportunity Applied' Name='OpportunityApplied' " + `
    "List='$($oppList.Id)' ShowField='Title' Required='TRUE' />"
Add-PnPFieldFromXml -List $appListName -FieldXml $lookupFieldXml

Add-PnPField -List $appListName -DisplayName "Applicant Email" -InternalName "ApplicantEmail" `
    -Type Text -AddToDefaultView -Required

Add-PnPField -List $appListName -DisplayName "Manager Email" -InternalName "ManagerEmail" `
    -Type Text -AddToDefaultView -Required

Add-PnPField -List $appListName -DisplayName "Skills Summary" -InternalName "SkillsSummary" `
    -Type Note -AddToDefaultView -Required

Add-PnPField -List $appListName -DisplayName "Availability" -InternalName "Availability" `
    -Type Choice -Choices "Immediate", "2 Weeks", "1 Month" `
    -AddToDefaultView -Required

Add-PnPField -List $appListName -DisplayName "Status" -InternalName "Status" `
    -Type Choice -Choices "Submitted", "Shortlisted", "Scheduled", "Rejected" `
    -AddToDefaultView -Required

# Default values
Set-PnPField -List $appListName -Identity "Status" -Values @{ DefaultValue = "Submitted" }

# Indexing
Set-PnPField -List $appListName -Identity "Status" -Values @{ Indexed = $true }
Set-PnPField -List $appListName -Identity "EmployeeID" -Values @{ Indexed = $true }

# Manager working queue view (fallback if a card action is missed)
if (-not (Get-PnPView -List $appListName -Identity "SPARK_Pending_Review" -ErrorAction SilentlyContinue)) {
    Add-PnPView -List $appListName -Title "SPARK_Pending_Review" `
        -Fields "Title", "EmployeeID", "OpportunityApplied", "Availability", "Status" `
        -Query "<Where><Eq><FieldRef Name='Status'/><Value Type='Choice'>Submitted</Value></Eq></Where>"
    Write-Host "Created view SPARK_Pending_Review" -ForegroundColor Green
}

Write-Host "$appListName provisioned." -ForegroundColor Green

# ============================================================
# GOVERNANCE: item-level read/write restriction on SPARK_Applications
# (freshers should only see/edit applications they created themselves)
# ============================================================
Write-Host "Configuring item-level permissions on $appListName ..." -ForegroundColor Yellow

$list = Get-PnPList -Identity $appListName
$list.WriteSecurity = 2   # 2 = users may edit only items they created
$list.ReadSecurity = 2    # 2 = users may read only items they created
$list.Update()
Invoke-PnPQuery

Write-Host "`nSchema provisioning complete." -ForegroundColor Cyan
Write-Host "Manual follow-up steps (not automatable without knowing your tenant's group names):" -ForegroundColor Yellow
Write-Host " 1. Break role inheritance on $appListName (Set-PnPList / list permissions UI) and grant"
Write-Host "    your Managers/HR security group 'Contribute' at the LIST level so they can see all applications"
Write-Host "    (item-level security above only restricts the default/fresher permission level, not owners)."
Write-Host " 2. Apply SPARK_Opportunities-ViewFormatting.json to the SPARK_Active_Opportunities view"
Write-Host "    via: List -> View options -> Format current view -> Advanced mode -> paste JSON."
Write-Host " 3. Hide Status and ManagerEmail on the fresher-facing New Item form using Power Apps form customization."
