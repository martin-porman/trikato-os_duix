You are a senior visual product designer and frontend art director.

Design and implement a static, multi-screen HTML prototype for an internal accounting operations product called “Trikato OS”.

Important:
- You do NOT have access to any prior HTML files.
- Recreate the product from the specification below only.
- Do NOT copy a generic SaaS dashboard aesthetic.
- You must invent your own visual style.
- Even with a new style, you must preserve the presentation logic, screen hierarchy, information density, and navigation behavior described here.

Core intent:
This is a worker-first accounting operations interface, not a marketing site.
It is for accountants and team leads managing:
- daily work queues
- incoming documents
- missing inputs
- approvals
- monthly compliance
- annual report work
- client-specific operating context

This prototype is an approval artifact only.
It must feel realistic, decisive, and operational.
It must not depend on live APIs or databases.

Deliverables:
Create a static prototype using:
- vanilla HTML
- vanilla CSS
- minimal vanilla JS only where helpful
- no frameworks
- no CDN assets
- no external fonts
- no broken links
- no placeholder links that go nowhere

Create these files:
- index.html
- toovoog.html
- vastavus.html
- klienditoimik.html
- assets/styles.css
- assets/app.js
- optionally a local favicon or local SVG assets if needed

Language:
- All user-facing copy must be in Estonian
- Use realistic accounting and workflow terms such as:
  - Pooleli
  - Puuduvad dokumendid
  - Aastaaruanne
  - TSD
  - KMD
  - Pank
  - Müük
  - Ost
  - Vajab kinnitamist

Data:
- Use sanitized but credible sample data
- The content should feel like a real accounting firm’s working environment
- Do not use confidential or obviously fake lorem ipsum content
- Every page must be self-sufficient above the fold so a reviewer understands the purpose even if they open only one page

Non-negotiable presentation rules:
- The product must be multi-screen, not one long page
- Every page must have persistent cross-page navigation
- Every page must also have page-local section navigation using real anchor targets
- There must be no dead links
- Navigation must feel deliberate and operational, not decorative
- Each screen must open with a strong hero area that immediately explains what this page helps the worker do
- Each page must feel like a working desk or control surface, not a template gallery
- The UI must privilege clarity, urgency, and next actions over decoration
- The interface should be information-dense, but still calm and readable

What the original prototype did structurally:
There were 4 pages with a consistent shared shell.

Shared shell requirements:
- A persistent left-side navigation rail or equivalent fixed navigation structure
- The rail contains:
  - product mark / title
  - a short intro sentence about the page
  - global navigation to all 4 pages
  - local navigation to the main sections of the current page
  - a short “principle” or “working rule” note
- The main content area contains large editorial sections composed of layered panels, cards, tables, note blocks, or timeline blocks

Shared visual behavior requirements:
- A strong display hierarchy:
  - small eyebrow label
  - large page statement / hero heading
  - explanatory paragraph
  - action links / quick links
- Distinct status signaling:
  - danger / blocked
  - warning / waiting
  - okay / complete
  - info / in progress
  - neutral / reference
- Reusable visual patterns:
  - status badges / pills
  - thin bordered panels
  - table-card hybrids
  - note blocks
  - timeline rows
  - filter chips
  - quick-link cards
- Use subtle motion only:
  - staged load-in
  - hover emphasis
  - filter state changes
  - slight panel lift or shift
- Motion must support readability, not feel flashy

Original design-system logic that must be preserved conceptually:
- Paper-like or editorial background atmosphere
- Deep ink typography
- A restrained but expressive semantic palette with roles comparable to:
  - paper
  - ink
  - bronze
  - moss
  - signal red
  - amber
  - steel-blue
- Display typography should feel refined and serious
- UI/body typography should feel human, readable, and tool-like
- No Arial, Inter, Roboto, or default generic modern startup styling
- No purple-gradient-on-white AI aesthetic
- No empty glossy cards with no operational meaning

You may choose a totally different visual language, but it must still feel:
- premium
- specific
- worker-first
- editorial
- trustworthy
- a little dense in a good way
- designed for accountants who are making judgment calls all day

Screen architecture:
You must build these exact 4 screen types.

1. index.html — Overview / command center
Purpose:
- high-level Trikato OS dashboard
- this is the “what needs attention today” page

Must include:
- hero section with page statement
- an aside or companion summary block with key counts
- a KPI strip or equivalent key-metrics row
- a “Vajab tähelepanu” area with priority cards
- a team load / worker load area
- an intake / pipeline explanation or system-state area
- a quick-links section that routes users into the 3 other workflow screens

The content logic should communicate:
- what is urgent
- who is overloaded
- what is blocked
- what is ready to close quickly
- what part of the system is feeding the work

2. toovoog.html — Workflow / queue / intake screen
Purpose:
- the operator’s daily work queue
- the place where intake, approvals, blockers, and period-based work are seen together

Must include:
- hero section
- a filterable “Pooleli” work area
- a queue of live work cards or panels
- an input board / intake table showing incoming files, source, period, type, next step
- a “Vajab kinnitamist” section for reports or OCR decisions
- a “Blokeeringud” section for missing inputs or waiting states
- a period-based or phase-based layout showing how work moves through the month

The content logic should communicate:
- what is actively in progress
- what is waiting on a person
- what is waiting on a client
- what can be closed quickly
- what exact next action is needed for each stuck item

3. vastavus.html — Compliance / deadline / annual report control board
Purpose:
- this is the obligations and deadlines screen

Must include:
- hero section
- a deadline-focused area for the next 14 days
- visual grouping by urgency or time horizon
- a monthly compliance matrix that brings together:
  - TSD
  - KMD
  - Pank
  - Ost / Müük
- an “Aastaaruande rada” section
- an escalation / partner-attention section

The content logic should communicate:
- deadline pressure in time
- whether the problem is missing data, missing decision, or missing execution
- which annual report items are red, yellow, or close to complete
- what must be escalated to a partner

4. klienditoimik.html — Client dossier / single-case working view
Purpose:
- one client seen as a full operating case

Must include:
- hero section naming the example client
- a current-state summary area
- a timeline / ajajoon section
- a documents section showing:
  - pank
  - ost
  - müük
  - what is missing
- a report / approval / submission section
- a notes / remarks / communication section

The content logic should communicate:
- what is true about this client right now
- what happened recently
- what is missing
- whether the report is ready
- what decision or client contact is next
- how freeform notes become visible structured working memory

Navigation rules:
- Every top-level nav item must point to a real local file that exists
- Every in-page nav item must point to a real anchor ID that exists on that page
- All quick links and CTA links must resolve correctly
- No external URLs
- No dummy “Learn more” style links
- No dead icons or missing images

Content style:
- Use strong, declarative language
- Favor “what happens next” over abstract descriptions
- Make the interface sound like it is helping someone work, not browse
- Keep it serious, operational, and human
- Avoid generic fintech buzzwords

Design freedom:
You are free to invent:
- a different palette
- a different typographic stack using local/system fonts only
- a different shape language
- a different grid system
- a different texture treatment
- a different visual metaphor

But you must preserve:
- multi-screen structure
- worker-first information architecture
- the 4 page purposes
- the section logic on each page
- dense editorial hierarchy
- strong status semantics
- clear next actions
- fixed/persistent navigation behavior
- static local-only implementation

Do not do these things:
- do not make it look like a generic admin template
- do not make it mostly empty whitespace with a few oversized cards
- do not make it feel like a brand landing page first and operations product second
- do not rely on charts alone to communicate operational state
- do not use external font imports
- do not use CDNs
- do not output broken links
- do not use filler lorem ipsum
- do not reduce everything into a single dashboard page

Implementation expectation:
Return the complete code for the files.
Use shared CSS and shared JS.
Keep JS minimal and optional.
The pages must still read correctly if JS fails.
Use only local assets.

Before finalizing your output, verify internally that:
- all 4 HTML pages exist
- all nav links resolve
- all local anchors exist
- no external dependencies are used
- the pages are responsive on desktop and mobile
- the design feels intentional and non-generic
- the interface is clearly for accountants doing real daily work

Output format:
1. A very short concept summary
2. The file tree
3. Full code for every file
