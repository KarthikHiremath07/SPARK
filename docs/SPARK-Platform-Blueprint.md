# SPARK Platform — Prototype Blueprint
### Microsoft 365 Native Opportunity Marketplace with Closed-Loop Automation

---

## PHASE 1 — DATA LAYER (Microsoft Lists Schema)

### 1.1 List: `SPARK_Opportunities`

| Internal Name | Display Name | Type | Config |
|---|---|---|---|
| `Title` | Project Title | Single line of text | Required, indexed |
| `Domain` | Domain | Choice | Values: `AI/ML`, `Cloud`, `Data`, `Frontend`, `Backend`, `DevOps`, `Design` — allow fill-in: No |
| `RequiredSkills` | Required Skills | Single line of text | Required |
| `TechStack` | Tech Stack | Single line of text | Comma-separated tags, used in card formatting |
| `Openings` | Openings | Number | Min 0, no decimals, default 1 |
| `MentorName` | Mentor Name | Person or Group | Single value, "Show as" = Name only |
| `Status` | Status | Choice | Values: `Open`, `Under Review`, `Closed` — default: `Open` |
| `Created` | (system) | — | Used for "Newest first" default sort |

**Indexing:** Add a managed index on `Status` and `Domain` (List Settings → Indexed Columns). Both are used as filter criteria in views and in the list view web part, and SharePoint list view thresholds (5,000 items) require indexed columns on any filtered field to remain performant at scale.

**Default view filter:** `SPARK_Active_Opportunities` view filtered on `Status = Open`, sorted `Created` descending. This is the view embedded on the portal homepage — never expose the raw "All Items" view to fresher-facing pages.

---

### 1.2 List: `SPARK_Applications`

| Internal Name | Display Name | Type | Config |
|---|---|---|---|
| `Title` | Applicant Name | Single line of text | Required |
| `EmployeeID` | Employee ID | Single line of text | Required, indexed (used for duplicate-application lookups) |
| `OpportunityApplied` | Opportunity Applied | Lookup → `SPARK_Opportunities.Title` | Required. Prefer Lookup over free text so the workflow can resolve the source item and pull Mentor/Domain without re-typing |
| `ApplicantEmail` | Applicant Email | Single line of text (or Person) | Required. Use Person type if all freshers have AAD accounts — enables `[$ApplicantEmail].email` dynamic content directly. Otherwise plain text validated as email format |
| `ManagerEmail` | Manager Email | Single line of text (or Person) | Required, same reasoning as above |
| `SkillsSummary` | Skills Summary | Multiple lines of text (plain) | Required |
| `Availability` | Availability | Choice | Values: `Immediate`, `2 Weeks`, `1 Month` |
| `Status` | Status | Choice | Values: `Submitted`, `Shortlisted`, `Scheduled`, `Rejected` — default: `Submitted` |

**Indexing:** Index `Status` and `EmployeeID`. Index `Status` because the flow and any dashboard views filter on it; index `EmployeeID` if you later add a "one application per opportunity" duplicate check via a Get Items call.

**Default view filter:** `SPARK_Pending_Review` filtered on `Status = Submitted`, used by managers as a working queue outside of the Adaptive Card flow (fallback path if a card action fails or is missed).

**Governance note:** Set unique permissions on `SPARK_Applications` so freshers have `Contribute` (create/read own items only via item-level permissions: List Settings → Advanced Settings → "Read access: Read items that were created by the user" and "Create and Edit access: Create items and edit items that were created by the user"). Managers/HR get `Contribute` at list level; Fresher-facing form web part should never expose the `Status` or `ManagerEmail` fields for edit.

---

## PHASE 2 — MODERN DYNAMIC UI

### 2.1 List View Formatting JSON — `SPARK_Opportunities`

Apply via: List → View options (⋯) → **Format current view** → Advanced mode → paste below.

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/view-formatting.schema.json",
  "hideSelection": true,
  "hideListHeader": true,
  "rowFormatter": {
    "elmType": "div",
    "attributes": {
      "class": "spark-card"
    },
    "style": {
      "display": "flex",
      "flex-direction": "column",
      "border-radius": "16px",
      "padding": "20px 22px",
      "margin-bottom": "14px",
      "background": "linear-gradient(145deg, rgba(255,255,255,0.65), rgba(255,255,255,0.35))",
      "backdrop-filter": "blur(14px)",
      "border": "1px solid rgba(255,255,255,0.5)",
      "box-shadow": "0 4px 16px rgba(15,23,42,0.08)",
      "transition": "transform 0.18s ease, box-shadow 0.18s ease",
      "cursor": "pointer"
    },
    "children": [
      {
        "elmType": "div",
        "style": {
          "display": "flex",
          "justify-content": "space-between",
          "align-items": "center",
          "margin-bottom": "10px"
        },
        "children": [
          {
            "elmType": "span",
            "txtContent": "[$Domain]",
            "style": {
              "font-size": "11px",
              "font-weight": "700",
              "letter-spacing": "0.04em",
              "text-transform": "uppercase",
              "padding": "4px 10px",
              "border-radius": "999px",
              "color": "#ffffff",
              "background-color": "=if(@currentField == 'AI/ML', '#7C3AED', if(@currentField == 'Cloud', '#0EA5E9', if(@currentField == 'Data', '#059669', if(@currentField == 'Frontend', '#F59E0B', if(@currentField == 'Backend', '#DC2626', if(@currentField == 'DevOps', '#334155', '#DB2777'))))))"
            }
          },
          {
            "elmType": "span",
            "txtContent": "[$Status]",
            "style": {
              "font-size": "11px",
              "font-weight": "600",
              "padding": "4px 10px",
              "border-radius": "999px",
              "color": "=if([$Status] == 'Open', '#065F46', '#7F1D1D')",
              "background-color": "=if([$Status] == 'Open', '#D1FAE5', '#FEE2E2')"
            }
          }
        ]
      },
      {
        "elmType": "div",
        "txtContent": "[$Title]",
        "style": {
          "font-size": "17px",
          "font-weight": "700",
          "color": "#0F172A",
          "margin-bottom": "6px"
        }
      },
      {
        "elmType": "div",
        "txtContent": "[$TechStack]",
        "style": {
          "font-size": "12.5px",
          "color": "#475569",
          "margin-bottom": "12px"
        }
      },
      {
        "elmType": "div",
        "style": {
          "display": "flex",
          "justify-content": "space-between",
          "align-items": "center",
          "border-top": "1px solid rgba(15,23,42,0.08)",
          "padding-top": "10px"
        },
        "children": [
          {
            "elmType": "div",
            "style": { "display": "flex", "align-items": "center", "gap": "6px" },
            "children": [
              {
                "elmType": "span",
                "txtContent": "Mentor:",
                "style": { "font-size": "11px", "color": "#94A3B8", "font-weight": "600" }
              },
              {
                "elmType": "span",
                "txtContent": "[$MentorName.title]",
                "style": { "font-size": "12.5px", "color": "#334155", "font-weight": "600" }
              }
            ]
          },
          {
            "elmType": "span",
            "txtContent": "=[$Openings] + ' openings'",
            "style": {
              "font-size": "12px",
              "font-weight": "700",
              "color": "#1D4ED8"
            }
          }
        ]
      }
    ]
  }
}
```

**Notes on production-readiness:**
- `MentorName.title` assumes a Person field; if kept as Single line of text, change the token to `[$MentorName]`.
- Add a hover effect via the site's SPFx extension or a small CSS injection (Communication Site theme customization) since inline row formatting JSON does not support `:hover` pseudo-selectors natively — the `transition` property above is prepared for that companion CSS: `.spark-card:hover { transform: translateY(-3px); box-shadow: 0 10px 24px rgba(15,23,42,0.14); }`.
- Test color contrast (WCAG AA) for the domain pill palette before final submission — some panel reviewers check accessibility explicitly.

### 2.2 Page Layout Plan — Communication Site

**Section 1 — Hero (Full-width section, 1 column)**
- Web part: **Hero**
- Layout: Big/Tiles disabled → use single large image layout
- Background: brand-neutral gradient image (1900×550px) or SPARK wordmark on dark navy
- Title: "SPARK — Find Your Next Opportunity"
- CTA button: "Browse Opportunities" → anchor-links to Section 2

**Section 2 — Opportunity Marketplace (One column, full-width)**
- Web part: **List** (modern List web part, not "Document Library")
- Source: `SPARK_Opportunities`, View: `SPARK_Active_Opportunities`
- Toggle "Show command bar" = Off (hide New/Edit/Export — read-only marketplace feel)
- Enable the JSON formatting from 2.1 at the list-view level so it renders identically wherever embedded

**Section 3 — Application Intake (One column, centered ~66% width)**
- Web part: **Microsoft Forms** (embedded) or **Power Apps** web part hosting a canvas form bound to `SPARK_Applications` — Power Apps preferred for field validation (e.g., blocking duplicate Employee ID + Opportunity combinations) and a cleaner conditional UI than the native SharePoint new-item form.
- If time-constrained for the prototype: use the native List web part's "+ New" form, customized with **Power Apps form customization** to hide `Status`/`ManagerEmail` and add a modern single-column layout with section headers.

**Section 4 — Footer / Status strip (Full-width, low visual weight)**
- Web part: **Text** — brief "How it works" 3-step microcopy (Discover → Apply → Get Matched) to reinforce the funnel visually without extra clutter.

**Global page settings:** Site theme customized (Site Settings → Change the look → Theme) with a neutral palette matching the card gradient in 2.1; turn off the default "Site activity" and "News" web parts on this page — panel graders penalize visual noise unrelated to the demo path.

---

## PHASE 3 — CLOSED-LOOP POWER AUTOMATE CLOUD FLOW

**Flow name:** `SPARK-Workflow-Engine`

### 3.1 Trigger
- Connector: **SharePoint — When an item is created**
- Site Address: SPARK site URL
- List Name: `SPARK_Applications`

### 3.2 Get Opportunity Context (recommended add-on)
- Action: **SharePoint — Get item**
- Site: SPARK site
- List: `SPARK_Opportunities`
- Id: `triggerOutputs()?['body/OpportunityApplied/Id']` *(requires the Lookup column config from Phase 1; if using text, skip this step and use the typed value directly)*
- Purpose: resolves Mentor Name / Tech Stack so the Adaptive Card doesn't rely solely on freetext entered by the applicant.

### 3.3 Manager Adaptive Card (Post card and wait for a response)
- Action: **Microsoft Teams — Post adaptive card and wait for a response**
- Recipient: `triggerOutputs()?['body/ManagerEmail']` (or `body('Get_item')?['ManagerEmail/Email']` if Person type)
- Message (Adaptive Card JSON):

```json
{
  "type": "AdaptiveCard",
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "version": "1.4",
  "body": [
    {
      "type": "TextBlock",
      "text": "New Application — Action Required",
      "weight": "Bolder",
      "size": "Medium",
      "color": "Accent"
    },
    {
      "type": "FactSet",
      "facts": [
        { "title": "Candidate:", "value": "@{triggerOutputs()?['body/Title']}" },
        { "title": "Employee ID:", "value": "@{triggerOutputs()?['body/EmployeeID']}" },
        { "title": "Opportunity:", "value": "@{triggerOutputs()?['body/OpportunityApplied/Value']}" },
        { "title": "Availability:", "value": "@{triggerOutputs()?['body/Availability/Value']}" }
      ]
    },
    {
      "type": "TextBlock",
      "text": "Skills Summary",
      "weight": "Bolder",
      "spacing": "Medium"
    },
    {
      "type": "TextBlock",
      "text": "@{triggerOutputs()?['body/SkillsSummary']}",
      "wrap": true
    }
  ],
  "actions": [
    {
      "type": "Action.Submit",
      "title": "Shortlist",
      "data": { "action": "Shortlist" }
    },
    {
      "type": "Action.Submit",
      "title": "Schedule Discussion",
      "data": { "action": "Schedule" }
    }
  ]
}
```

- Timeout: set to `P3D` (3 days) at the action's settings level so unresponsive managers auto-fallback rather than blocking the flow indefinitely.
- Output used downstream: `body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action']`

*(If Teams Adaptive Card connector isn't licensed/available in the tenant, substitute with the **Outlook — Send approval email** action using two custom "Options" (`Shortlist`, `Schedule Discussion`) as a structured fallback; the branching logic below is identical, just swap the output expression to `body('Send_approval_email')?['SelectedOption']`.)*

### 3.4 Condition — Branch on Manager Response

- Condition: `@equals(body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action'], 'Shortlist')`

**If Yes (Shortlist branch):**
- Action: **SharePoint — Update item**
- List: `SPARK_Applications`
- Id: `triggerOutputs()?['body/ID']`
- Status: `Shortlisted`

**If No → nested condition:** `@equals(body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action'], 'Schedule')`
- **If Yes (Schedule branch):**
  - Action: **SharePoint — Update item**
  - Id: `triggerOutputs()?['body/ID']`
  - Status: `Scheduled`
- **If No (timeout / no response):**
  - Action: **SharePoint — Update item**
  - Status: left unchanged, or set to a holding value; log via **Compose** action for audit (`"No manager response within SLA"`).

### 3.5 Automated Feedback Loop (Candidate Notification)

- Action: **Office 365 Outlook — Send an email (V2)**
- To: `triggerOutputs()?['body/ApplicantEmail']`
- Subject: `Update on your SPARK application — @{triggerOutputs()?['body/OpportunityApplied/Value']}`
- Body (dynamic, HTML-enabled):

```
Hi @{triggerOutputs()?['body/Title']},

Your application for "@{triggerOutputs()?['body/OpportunityApplied/Value']}" has been updated:

Status: @{if(equals(body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action'], 'Shortlist'), 'Shortlisted', if(equals(body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action'], 'Schedule'), 'Scheduled for a discussion', 'Under review'))}

@{if(equals(body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action'], 'Schedule'), 'Your mentor will reach out shortly to confirm a time.', 'Youll hear back with next steps soon.')}

— SPARK Platform
```

**Key dynamic-token reference sheet:**
| Purpose | Expression |
|---|---|
| Applicant name | `triggerOutputs()?['body/Title']` |
| Applicant email | `triggerOutputs()?['body/ApplicantEmail']` |
| Manager email | `triggerOutputs()?['body/ManagerEmail']` |
| Item ID for update | `triggerOutputs()?['body/ID']` |
| Manager's action choice | `body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action']` |
| Opportunity title (Lookup) | `triggerOutputs()?['body/OpportunityApplied/Value']` |

---

## PHASE 4 — EXECUTIVE 60-SECOND DEMO TALK TRACK

**00:00–00:15 | Portal & UX Showcase**
"This is SPARK — built natively on SharePoint and Power Platform, so it sits inside the tools we already use, with zero new licensing cost. What you're seeing isn't a default list — every opportunity card is custom-formatted: domain tags, mentor, openings, live status — all responsive, all governed."

**00:15–00:30 | Live Submission**
"A fresher browsing here clicks into an opportunity and applies directly through this intake form. Notice it's clean, single-column, and only asks for what's needed — skills, availability, and the role they want."

**00:30–00:45 | Trigger & Manager Card**
"The moment that application lands, Power Automate fires instantly — the manager gets an Adaptive Card right in Teams, with the candidate's full context and two one-tap actions: Shortlist or Schedule. No inbox digging, no manual list."

**00:45–01:00 | Status Update & Closed Loop**
"One tap — and watch the SharePoint list update live to 'Shortlisted,' while the candidate simultaneously gets an automated email confirming their status. Full loop, zero manual follow-up, end to end in seconds — that's SPARK."

---

### Pre-Submission Checklist
- [ ] Both lists created with indexed columns and item-level permissions on `SPARK_Applications`
- [ ] JSON view formatting validated in SharePoint's formatting panel (no syntax errors)
- [ ] Adaptive Card tested with both action buttons in a real Teams DM
- [ ] Condition branches tested for all 3 outcomes (Shortlist / Schedule / Timeout)
- [ ] Candidate email tested for correct dynamic status text in each branch
- [ ] Demo environment seeded with 3–4 realistic sample opportunities before the panel review
