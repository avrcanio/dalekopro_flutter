# AGENTS.md - Dalekopro Flutter

## Project Context
- Project type: Flutter (Android-first).
- Reference issue: `https://github.com/avrcanio/dalekopro/issues/1`.
- Migrated origin: `https://github.com/mojafarma/moja-farma/issues/3`.
- Primary business flow: `login -> gospodarstva -> goveda -> detalj -> slika -> crop -> odabir goveda -> upload`.

## Locked Assumptions
- Repo may start empty; this file lives in project root.
- Target mobile OS is Android (Samsung and other Android OEM devices); iOS is out of current scope.
- API contract from issue remains valid:
  - `POST /api/auth/login/`
  - `GET /api/gospodarstva/`
  - `GET /api/gospodarstva/{id}/animals/`
  - `POST /api/slike_goveda/upload/`

## GitHub CLI and Auth Rules
- Use GitHub CLI (`gh`) for issue and PR context.
- Read token from `C:\Users\avrca\Documents\Projects\hosts.yml`.
- Never print token values in logs, terminal output, code comments, or final reports.
- Allowed handling: set token only in session env var `GH_TOKEN`.
- Standard workflow commands:

```powershell
# 1) Load GH token from hosts.yml into session env var
$token = (Select-String -Path "C:\Users\avrca\Documents\Projects\hosts.yml" -Pattern 'oauth_token:\s*(\S+)' | Select-Object -First 1).Matches[0].Groups[1].Value
$env:GH_TOKEN = $token

# 2) Read reference issue
gh issue view 1 --repo avrcanio/dalekopro

# 3) Read issue with machine-readable fields
gh issue view 1 --repo avrcanio/dalekopro --json number,title,body,state,labels,assignees
```

## Flutter Implementation Standard (Issue #1 Scope)

### 1) Setup and Architecture
- Keep modular feature layout:
  - `features/auth`
  - `features/farms`
  - `features/cattle`
  - `features/upload`
- Use `dio` with global interceptor:
  - Send `Authorization: Token <token>` on authenticated requests.
- Store token securely using `flutter_secure_storage`.
- Keep central `ApiConfig` for base URL, timeout, and retry policy for network errors.

### 2) Auth Flow
- Login screen: `username`, `password`.
- Endpoint: `POST /api/auth/login/`.
- Persist token and basic user payload after success.
- Route guard behavior:
  - no token -> `Login`
  - token exists -> `Home`
- Show clear user-facing messages for `400`, `401`, and connectivity failures.

### 3) Farms and Cattle Listing
- Fetch farms from `GET /api/gospodarstva/`.
- If multiple farms exist, require active farm selection.
- Fetch animals from `GET /api/gospodarstva/{id}/animals/`.
- List item baseline: image, `zivotni_broj`, name.
- Include pull-to-refresh and explicit loading/empty/error states.

### 4) Cattle Details and Descendants
- Details screen fields: `zivotni_broj`, name, calving date, sex, age, mother, father.
- Prefer `potomci` from API.
- Backward compatibility rule: if `potomci` missing, fallback to `telad`.

### 5) Camera, Folder Source, Crop, and Upload
- Camera capture stack is fixed for this scope:
  - `image_picker` with `source: camera`.
- Folder source selection is fixed for this scope:
  - User picks folder via Android SAF.
  - Persist selected folder URI for next sessions.
  - Use selected folder as image source for upload flow.
- Before upload, user must get preview/edit step:
  - enable zoom and crop with `image_cropper`.
- Attach metadata when available:
  - `datum`
  - `latitude`
  - `longitude`
- User must select cattle (`zivotni_broj`) from backend data before submit.
- Upload format:
  - `multipart/form-data`
  - endpoint `POST /api/slike_goveda/upload/`
  - fields: required `zivotni_broj`, required image file, optional `datum`, optional GPS.
- Error mapping requirements:
  - `400`: validation details (date/coords/request body)
  - `401`: auth/session problem
  - `404`: missing cattle by `zivotni_broj`

## Quality Guardrails
- Keep API models resilient to optional fields and backend evolution.
- Do not introduce breaking changes to existing app behavior outside issue scope.
- Keep UX explicit at each async state (loading, success, empty, error).
- Preserve telemetry/debug logs without leaking secrets or personal data.

## Test Standard
- Unit test: auth repository success/failure mapping.
- Unit test: cattle mapper (`potomci` with fallback `telad`).
- Widget test: login validation and error rendering.
- Integration/widget flow test: `login -> farms -> cattle list -> detail -> image select/crop -> cattle select -> upload`.

## Acceptance Checklist
- `AGENTS.md` exists in root and reflects issue `avrcanio/dalekopro#1`.
- Stack explicitly defined: `image_picker + image_cropper`.
- Folder behavior explicitly defined: Android SAF user-selected folder with persisted URI.
- Security rule included: GH token must never be exposed.
- End-to-end instructions are decision-complete for camera/folder/crop/cattle-link/upload flow.

## Kluster Policy
- `kluster_code_review_auto` is disabled for this repository.
- Do not use `kluster_code_review_auto` in this project workflow.
