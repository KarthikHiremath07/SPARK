<#
.SYNOPSIS
    Builds the SPARK Communication Site portal page (Phase 2.2 layout) with the
    Hero, List (Opportunities), Power Apps/Forms intake placeholder, and Text
    web parts placed in the order specified in the blueprint.

.DESCRIPTION
    Requires PnP.PowerShell and must be run AFTER provision-spark-lists.ps1
    has created SPARK_Opportunities, and after the view formatting JSON has
    been applied to the SPARK_Active_Opportunities view (Phase 2.1), since this
    script embeds that view.

    Run:
        .\provision-spark-page.ps1 -SiteUrl "https://<tenant>.sharepoint.com/sites/SPARK" `
            -HeroImageUrl "https://<tenant>.sharepoint.com/sites/SPARK/SiteAssets/hero.jpg"

.NOTES
    Web part property payloads for the modern List web part and Hero web part
    are set via their JSON properties schema, which can shift slightly between
    tenant releases. If Add-PnPPageWebPart -WebPartProperties rejects a property,
    open the page in the browser, add the web part manually once, then use
    Export the page and inspect Get-PnPPage / Get-PnPPageComponent to read back
    the exact current property names for your tenant build and adjust below.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [Parameter(Mandatory = $false)]
    [string]$HeroImageUrl = "",

    [Parameter(Mandatory = $false)]
    [string]$PageName = "SPARK-Home"
)

$ErrorActionPreference = "Stop"

Import-Module PnP.PowerShell -ErrorAction Stop

Write-Host "Connecting to $SiteUrl ..." -ForegroundColor Cyan
Connect-PnPOnline -Url $SiteUrl -Interactive

# Create the page if it doesn't already exist
if (-not (Get-PnPPage -Identity $PageName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating page $PageName ..." -ForegroundColor Yellow
    Add-PnPPage -Name $PageName -LayoutType Article -Publish:$false | Out-Null
}

$page = Get-PnPPage -Identity $PageName

# ------------------------------------------------------------
# SECTION 1: Hero (full-width, 1 column)
# ------------------------------------------------------------
Add-PnPPageSection -Page $page -SectionTemplate OneColumnFullWidth -Order 1

$heroProps = @{
    title       = "SPARK - Find Your Next Opportunity"
    description = "Discover, apply, and get matched - all in one place."
    ctaText     = "Browse Opportunities"
    ctaLink     = "#opportunities"
}
if ($HeroImageUrl -ne "") { $heroProps["imageSourceType"] = 4; $heroProps["altText"] = "SPARK banner" }

Add-PnPPageWebPart -Page $page -DefaultWebPartType Hero -Section 1 -Column 1 `
    -WebPartProperties (ConvertTo-Json $heroProps -Compress)

# ------------------------------------------------------------
# SECTION 2: Opportunity Marketplace (one column, full width)
#   NOTE: run this AFTER SPARK_Opportunities exists and the
#   SPARK_Active_Opportunities view has formatting applied.
# ------------------------------------------------------------
Add-PnPPageSection -Page $page -SectionTemplate OneColumnFullWidth -Order 2

$oppList = Get-PnPList -Identity "SPARK_Opportunities" -ErrorAction Stop
$activeView = Get-PnPView -List $oppList -Identity "SPARK_Active_Opportunities" -ErrorAction Stop

$listWebPartProps = @{
    isDocumentLibrary   = $false
    selectedListId      = $oppList.Id.ToString()
    selectedViewId      = $activeView.Id.ToString()
    webId               = (Get-PnPWeb).Id.ToString()
    siteId              = (Get-PnPSite).Id.ToString()
    showCommandBar      = $false
    showFilters         = $true
}

Add-PnPPageWebPart -Page $page -DefaultWebPartType List -Section 2 -Column 1 `
    -WebPartProperties (ConvertTo-Json $listWebPartProps -Compress)

# ------------------------------------------------------------
# SECTION 3: Application intake form (one column, ~centered)
#   Placeholder using the native List form web part pointed at
#   SPARK_Applications. Swap for the Power Apps web part if using
#   a customized canvas form - see comment below.
# ------------------------------------------------------------
Add-PnPPageSection -Page $page -SectionTemplate OneColumn -Order 3

$appList = Get-PnPList -Identity "SPARK_Applications" -ErrorAction Stop
$newItemFormProps = @{
    isDocumentLibrary = $false
    selectedListId    = $appList.Id.ToString()
    webId             = (Get-PnPWeb).Id.ToString()
    siteId            = (Get-PnPSite).Id.ToString()
    formType          = "New"
}

# If you built a Power Apps canvas form instead, replace this call with:
#   Add-PnPPageWebPart -Page $page -DefaultWebPartType PowerApps -Section 3 -Column 1 `
#       -WebPartProperties (ConvertTo-Json @{ appId = "<your-canvas-app-guid>" } -Compress)
Add-PnPPageWebPart -Page $page -DefaultWebPartType List -Section 3 -Column 1 `
    -WebPartProperties (ConvertTo-Json $newItemFormProps -Compress)

# ------------------------------------------------------------
# SECTION 4: Footer / "How it works" strip (full width, text only)
# ------------------------------------------------------------
Add-PnPPageSection -Page $page -SectionTemplate OneColumnFullWidth -Order 4

Add-PnPPageTextPart -Page $page -Section 4 -Column 1 -Text `
    "<h3>How it works</h3><p><strong>1. Discover</strong> - browse live opportunities below. " + `
    "<strong>2. Apply</strong> - submit a short intake form. " + `
    "<strong>3. Get Matched</strong> - your manager reviews and responds within days.</p>"

Set-PnPPage -Identity $page -HeaderLayoutType NoImage
Save-PnPPage -Identity $page

Write-Host "`nPage '$PageName' built. Publish it manually once you've verified the layout in the browser:" -ForegroundColor Cyan
Write-Host "  Set-PnPPage -Identity '$PageName' -Publish"
Write-Host "`nManual follow-up:" -ForegroundColor Yellow
Write-Host " - Turn off default News/Site Activity web parts if they were auto-added to the page template."
Write-Host " - Apply the site theme (Site Settings -> Change the look) to match the card palette."
