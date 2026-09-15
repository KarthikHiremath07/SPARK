# SPARK — Manual Browser Setup (No PowerShell, No Admin Needed)

You are a **Site Owner** on your team site. That permission level is enough, by
itself, to create lists, format views, build pages, and build the Power Automate
flow — all through the browser. None of it touches Entra ID app registrations, so
the permission wall you hit yesterday doesn't apply to any of this. Forget the
`.ps1` scripts; this replaces them entirely and produces the exact same result,
live in your real site.

Total time: ~30–40 minutes.

---

## PHASE 1 — Build the two lists

### List 1: `SPARK_Opportunities`

- Go to your site → **New** → **List** → **Blank list**
- Name it exactly: `SPARK_Opportunities` → **Create**
- You'll land on the list. Now add each column below using **+ Add column** (top of the list grid):

| Column name | Type | Settings |
|---|---|---|
| Domain | Choice | Choices: `AI/ML`, `Cloud`, `Data`, `Frontend`, `Backend`, `DevOps`, `Design`. Toggle **Require that this column contains information** = Yes |
| Required Skills | Single line of text | Require = Yes |
| Tech Stack | Single line of text | — |
| Openings | Number | Default value = `1` (set under column settings → Default value) |
| Mentor Name | Person | — |
| Status | Choice | Choices: `Open`, `Under Review`, `Closed`. Default value = `Open`. Require = Yes |

- **Title** column already exists by default — this is your "Project Title" field, no need to recreate it.
- **Index the filtered columns:** go to the gear icon (top right) → **List settings** → under **Columns**, click **Indexed columns** → **Create a new index** → choose `Status` → Create. Repeat for `Domain`.
- **Create the marketplace view:** click the current view name (top left of the grid) → **Create new view** → name it `SPARK_Active_Opportunities` → under filters, set **Show items only when:** `Status is equal to Open` → sort by `Created` descending → **Create**.

### List 2: `SPARK_Applications`

- Site → **New** → **List** → **Blank list** → name it `SPARK_Applications`
- Add columns:

| Column name | Type | Settings |
|---|---|---|
| Employee ID | Single line of text | Require = Yes |
| Opportunity Applied | Lookup | Get information from: `SPARK_Opportunities`, In this column: `Title`. Require = Yes |
| Applicant Email | Single line of text | Require = Yes |
| Manager Email | Single line of text | Require = Yes |
| Skills Summary | Multiple lines of text (plain text) | Require = Yes |
| Availability | Choice | Choices: `Immediate`, `2 Weeks`, `1 Month` |
| Status | Choice | Choices: `Submitted`, `Shortlisted`, `Scheduled`, `Rejected`. Default = `Submitted` |

- **Index:** List settings → Indexed columns → add `Status` and `Employee ID`.
- **Manager working view:** create a view `SPARK_Pending_Review` filtered on `Status is equal to Submitted`.
- **Item-level permission lock (optional but recommended):** List settings → **Advanced settings** → under *Item-level Permissions*:
  - Read access → **Read items that were created by the user**
  - Create and Edit access → **Create items and edit items that were created by the user**
  - Then separately go to the list's **Permissions** (gear → List settings → Permissions for this list) → break inheritance → add your Managers/HR group with **Edit** or **Contribute** at the list level, so they can see everyone's applications.

---

## PHASE 2 — Modern UI

### 2.1 Apply the card formatting (browser only, no PowerShell)

- Open `SPARK_Opportunities` → open the `SPARK_Active_Opportunities` view
- Click the view name → **Format current view**
- In the panel, click **Advanced mode** — a text box appears
- Open the file `SPARK_Opportunities-ViewFormatting.json` (from the earlier package), select all, copy
- Paste it into the box, replacing the placeholder JSON → **Save**
- The list should now render as styled cards instead of a plain table.

### 2.2 Build the page

- Site → **New** → **Page** → choose **Blank** (or "Article", either works) → name it `SPARK-Home`
- **Section 1 (Hero):** click **+** to add a section → choose full-width, one column → add the **Hero** web part → set title "SPARK — Find Your Next Opportunity", add a background image if you have one, and set the button text to "Browse Opportunities"
- **Section 2 (Marketplace):** add another full-width section → add the **List** web part → in its settings pick the `SPARK_Opportunities` list and the `SPARK_Active_Opportunities` view → turn off the command bar in the web part's edit panel
- **Section 3 (Apply):** add a one-column section → add the **List** web part again, this time pointed at `SPARK_Applications`, and set its "web part type" to show the New Item form if available, or simply link a button here to the list's `/Forms/NewForm.aspx` page
- **Section 4 (Footer):** add a **Text** web part with a short "How it works: Discover → Apply → Get Matched" blurb
- Click **Publish** (top right) once it looks right.

---

## PHASE 3 — Power Automate flow (browser only)

This part **never needed PowerShell or Entra app registration** — Power Automate's
maker portal uses its own first-party connectors (SharePoint, Teams, Outlook) that
are pre-consented for any licensed user in most tenants. Go straight to
**make.powerautomate.com** and follow `SPARK-Workflow-Engine-BuildGuide.md` from
the earlier package, step by step. Quick recap of what it has you do:

1. New flow → trigger: **SharePoint — When an item is created** on `SPARK_Applications`
2. Action: **Microsoft Teams — Post adaptive card and wait for a response**, pasting in `SPARK-ManagerAdaptiveCard.json`
3. **Condition** branching on Shortlist / Schedule / no response
4. **SharePoint — Update item** to set Status in each branch
5. **Outlook — Send an email (V2)** back to the applicant

**If Step 2 fails or the Teams connector isn't available to you:** the guide
includes a fallback using **Outlook — Send approval email** with two custom
options instead of an Adaptive Card — functionally identical, just a plainer UI.
Try Step 2 first; only fall back if it genuinely doesn't work.

**If Power Automate itself won't let you create a flow at all** (e.g. "you don't
have a license" or a DLP policy block) — that's the one part of this that could
still need an admin. But try it directly first: most standard Microsoft 365
licenses (including the free "per-user" Power Automate plan bundled into
Microsoft 365) can create flows using SharePoint/Outlook connectors without any
extra purchase or admin action.

---

## What to actually demo to the panel

Once Phases 1–3 are live on your real site, you have the *actual* thing, not a
simulation — the panel can watch a real SharePoint list, real Adaptive Card, and
real status update happen in your tenant. Keep the standalone HTML prototype
(`SPARK-Prototype.html`) as a backup slide/tab in case anything flakes live
during the demo (Teams card delivery can occasionally lag by a minute) — flipping
to the working local demo as a safety net costs you nothing and looks
intentional, not like a fallback.

---

### If any single step above throws an error
Screenshot it and send it over — at this point every remaining step is a normal
browser action a Site Owner is allowed to do, so any error here is much more
likely to be a quick fix (wrong column type, wrong view name) than another
permissions wall.
