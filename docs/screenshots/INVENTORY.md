# Documentation Screenshot Inventory Plan

Purpose
- Identify documentation pages and sections that would benefit from screenshots and provide standardized placeholders in the docs and test suite to generate them.

Process
1. Scan docs/ for user-facing guides, READMEs, and system docs that describe UI flows.
2. For each page, add an image placeholder with instructions for the screenshot engine (see `PLACEHOLDER_FORMAT` below).
3. Create a corresponding spec under `spec/docs_screenshots/` that performs the actions to produce the screenshot and saves it into the `docs/screenshots` folder.
4. Run `bin/dc-run rake docs:screenshots` to generate images.

Priority targets
- Setup and onboarding screens
- Creating and managing resources (Offers, Requests, Agreements)
- Navigation and admin screens (roles, permissions)
- Community pages and profile flows
- Any complex form or process with multiple steps

PLACEHOLDER_FORMAT
Insert in markdown where a screenshot should appear:

```
![Alt text](screenshots/desktop/short_machine_name.png)
```

When the screenshot engine runs, it will look for specs that define `screenshot_name: 'short_machine_name'` and create the necessary images.

Maintenance
- Keep screenshots under `docs/screenshots` and include both desktop and mobile variants when relevant.
- Update the spec placeholders when UI changes.
