# SPARK-Workflow-Engine — Power Automate Build Guide

Power Automate cloud flows can't be silently deployed from outside your tenant — a flow's
"actions" are bound to **connection references** (your Teams identity, your SharePoint
site auth, your Outlook mailbox) that only exist once you sign in inside Power Automate
itself. A `.zip` solution file built without those live connection IDs would fail to
import cleanly, so rather than hand you something that *looks* importable but breaks on
import, here is the exact, ordered build — every field value and expression is
copy-paste ready.

Total build time: ~10–15 minutes.

---

## Step 1 — Create the flow
1. **make.powerautomate.com** → **My flows** → **New flow** → **Automated cloud flow**
2. Name: `SPARK-Workflow-Engine`
3. Trigger: search **SharePoint**, choose **When an item is created**
4. Configure trigger:
   - **Site Address:** your SPARK site
   - **List Name:** `SPARK_Applications`
5. Click **Create**

## Step 2 — (Recommended) Resolve opportunity context
Add action → **SharePoint** → **Get item**
- **Site Address:** your SPARK site
- **List Name:** `SPARK_Opportunities`
- **Id:** insert dynamic content → `Opportunity Applied ID`
  *(only available if `OpportunityApplied` is a Lookup column, per the Phase 1 schema —
  if you used plain text instead, delete this step and reference the typed value
  directly in later steps)*

## Step 3 — Post the Adaptive Card to the manager
Add action → **Microsoft Teams** → **Post adaptive card and wait for a response**
- **Post as:** Flow bot (or your choice)
- **Post in:** Chat with a user
- **Recipient:** dynamic content → `Manager Email`
- **Message:** switch to **Code view** (the `</>` icon next to the card editor) and
  paste the contents of `SPARK-ManagerAdaptiveCard.json` (included alongside this file).
  Power Automate will substitute the `@{triggerOutputs()?[...]}` tokens with live data
  automatically — leave them exactly as written.
- Click the action's **⋯ (Settings)** → set **Timeout** to `P3D` (3 days) so an
  unresponsive manager doesn't block the flow indefinitely.

> **No Teams license / Adaptive Cards connector unavailable?** Replace this step with
> **Outlook — Send approval email**, using two custom options named `Shortlist` and
> `Schedule Discussion`. Everything downstream is identical — just change the output
> reference in Steps 4–5 from
> `body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action']` to
> `body('Send_approval_email')?['SelectedOption']`.

## Step 4 — Branch on the manager's response
Add action → **Control** → **Condition**
- Left value: dynamic content → expand **Expression** → paste:
  ```
  body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action']
  ```
- Operator: **is equal to**
- Right value: `Shortlist`

**If yes:**
Add action → **SharePoint — Update item**
- Site: SPARK site, List: `SPARK_Applications`
- **Id:** dynamic content → `ID` (from the trigger)
- **Status:** `Shortlisted`

**If no:** add a **nested Condition** inside the "If no" branch:
- Same left expression as above
- Operator: **is equal to**
- Right value: `Schedule`

  **If yes (nested):**
  Add action → **SharePoint — Update item** → same Id → **Status:** `Scheduled`

  **If no (nested — timeout/no response):**
  Add action → **Compose** → Input: `No manager response within SLA` (audit trail;
  optionally also update Status to a holding value of your choosing)

## Step 5 — Notify the candidate (closed loop)
Add this action **inside each of the three branches** from Step 4 (or after the whole
Condition block, using the same nested-if expression inline in the body — either
structure works; placing it inside each branch keeps the subject/body simplest).

Add action → **Office 365 Outlook — Send an email (V2)**
- **To:** dynamic content → `Applicant Email`
- **Subject:**
  ```
  Update on your SPARK application - @{triggerOutputs()?['body/OpportunityApplied/Value']}
  ```
- **Body** (switch to code view / HTML if you want formatting):
  ```
  Hi @{triggerOutputs()?['body/Title']},

  Your application for "@{triggerOutputs()?['body/OpportunityApplied/Value']}" has been updated:

  Status: [Shortlisted / Scheduled for a discussion / Under review — matching the branch you're in]

  [Your mentor will reach out shortly to confirm a time. / You'll hear back with next steps soon.]

  — SPARK Platform
  ```
  If you'd rather have one universal email action after the Condition instead of one
  per branch, use this single expression for the status line so it works in any branch:
  ```
  if(equals(body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action'], 'Shortlist'), 'Shortlisted', if(equals(body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action'], 'Schedule'), 'Scheduled for a discussion', 'Under review'))
  ```

## Step 6 — Save and test
1. **Save** the flow.
2. Go to the SPARK site → add a test item to `SPARK_Applications` with a real
   Manager Email you can check.
3. Confirm the Adaptive Card arrives in Teams, tap **Shortlist**, confirm:
   - The `SPARK_Applications` item's Status updates to `Shortlisted`
   - The applicant's inbox receives the confirmation email
4. Repeat with a second test item and tap **Schedule Discussion** to verify that branch too.
5. Check **Flow run history** (My flows → SPARK-Workflow-Engine → 28-day run history) for
   any failed steps before the demo.

---

### Full dynamic-token reference

| Purpose | Expression |
|---|---|
| Applicant name | `triggerOutputs()?['body/Title']` |
| Applicant email | `triggerOutputs()?['body/ApplicantEmail']` |
| Manager email | `triggerOutputs()?['body/ManagerEmail']` |
| Item ID for update | `triggerOutputs()?['body/ID']` |
| Manager's action choice | `body('Post_adaptive_card_and_wait_for_a_response')?['data']?['action']` |
| Opportunity title (Lookup) | `triggerOutputs()?['body/OpportunityApplied/Value']` |

**Action name note:** Power Automate auto-generates internal action names from the
display name with spaces replaced by underscores (e.g. "Post adaptive card and wait for
a response" → `Post_adaptive_card_and_wait_for_a_response`). If you rename the action in
the designer, update every expression above to match the new internal name, or the
`body(...)` references will fail to resolve.
