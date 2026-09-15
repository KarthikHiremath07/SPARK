# SPARK Platform — Implementation Package

## What's actually in this package
I don't have a live connection into your Microsoft 365 tenant from this chat — no
SharePoint, Teams, or Power Automate connector is available here — so I can't literally
click "Deploy" on your behalf. What I *can* do, and have done, is turn every part of the
blueprint into a concrete, executable artifact so implementing it in your tenant is a
run-the-script-and-paste-the-JSON exercise rather than a build-from-scratch one.

| File | What it does | How you use it |
|---|---|---|
| `01-SharePoint/scripts/provision-spark-lists.ps1` | Creates both Lists with every field, choice value, default, index, and view from Phase 1 | Run once in PowerShell against your site (see below) |
| `01-SharePoint/scripts/provision-spark-page.ps1` | Builds the Communication Site page with Hero / List / Form / Text sections from Phase 2.2 | Run after the lists exist and formatting is applied |
| `01-SharePoint/formatting/SPARK_Opportunities-ViewFormatting.json` | The glassmorphic card formatting from Phase 2.1 | Paste into the view's "Format current view → Advanced mode" panel |
| `02-PowerAutomate/SPARK-ManagerAdaptiveCard.json` | The manager notification card from Phase 3 | Paste into the Adaptive Card designer's code view inside the flow |
| `02-PowerAutomate/SPARK-Workflow-Engine-BuildGuide.md` | Exact, ordered steps to build the flow itself | Follow top to bottom in make.powerautomate.com |

Both JSON files have been validated as syntactically correct JSON. The PowerShell
scripts have been checked for balanced braces/parens and reviewed against current
PnP.PowerShell cmdlet syntax, but — being honest — I have not been able to execute them
against a live SharePoint tenant, so treat first run as a test on a non-production site
if you want a safety net, and read the inline comments; a couple of steps call out
tenant-specific values (site URL, hero image URL) only you can supply.

## Deployment order

1. **Install prerequisites** (once, on your machine):
   ```powershell
   Install-Module PnP.PowerShell -Scope CurrentUser
   ```
2. **Run the list provisioning script:**
   ```powershell
   .\01-SharePoint\scripts\provision-spark-lists.ps1 -SiteUrl "https://<tenant>.sharepoint.com/sites/SPARK"
   ```
   Sign in interactively when prompted. Confirm both lists and their views appear in
   the site.
3. **Apply the card formatting:** open `SPARK_Opportunities`, go to the
   `SPARK_Active_Opportunities` view → **Format current view** → **Advanced mode** →
   paste in `01-SharePoint/formatting/SPARK_Opportunities-ViewFormatting.json` → **Save**.
4. **Build the page:**
   ```powershell
   .\01-SharePoint\scripts\provision-spark-page.ps1 -SiteUrl "https://<tenant>.sharepoint.com/sites/SPARK" `
       -HeroImageUrl "https://<tenant>.sharepoint.com/sites/SPARK/SiteAssets/hero.jpg"
   ```
   Then open the page in the browser, sanity-check the layout, and publish it
   (`Set-PnPPage -Identity 'SPARK-Home' -Publish`).
5. **Build the flow:** open `02-PowerAutomate/SPARK-Workflow-Engine-BuildGuide.md` and follow it step by
   step in make.powerautomate.com, pasting `02-PowerAutomate/SPARK-ManagerAdaptiveCard.json` where
   directed.
6. **Governance follow-up** (flagged at the end of `01-SharePoint/scripts/provision-spark-lists.ps1`'s output
   too): break permission inheritance on `SPARK_Applications` and grant your
   Managers/HR group Contribute access at the list level, since the item-level
   security only restricts everyone else to their own submissions.
7. **Test end-to-end**: submit a test application, confirm the card reaches the
   manager, tap an action, confirm both the list status and the candidate email.
8. **Seed 3–4 real-looking sample opportunities** before the panel review, per the
   Phase 4 checklist.

## If something doesn't match your tenant exactly
Two spots are the most likely to need a tweak the first time you run them, both flagged
inline in the scripts:
- **Web part property names** in `01-SharePoint/scripts/provision-spark-page.ps1` (Hero/List web part JSON
  schemas can shift slightly between SharePoint releases). If a property is rejected,
  add that web part once by hand in the browser, then use `Get-PnPPage` /
  `Get-PnPPageComponent` to read back the exact property names your tenant expects.
- **`OpportunityApplied` as Lookup vs. text** — the script and flow guide both assume
  the Lookup configuration from the Phase 1 schema. If you simplified it to plain text
  during setup, the flow guide calls out the one line to change.

Everything else — field types, choice values, indexing, the card JSON, the flow
branching logic, and every dynamic-content expression — is copy-paste exact from the
approved blueprint.
