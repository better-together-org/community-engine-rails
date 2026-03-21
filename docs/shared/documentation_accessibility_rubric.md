# Documentation And In-Place Help Accessibility Rubric

This rubric is the canonical standard for Community Engine documentation, inline help text, hints, notices, and task guidance.

It is designed for users across technical skill levels and should be applied alongside WCAG 2.1 AA UI testing.

## Passing Standard

A surface passes when:

- all UI presentation meets WCAG 2.1 AA expectations
- no rubric category scores below `2`
- the total score is at least `12/16`
- any safety-critical or user-blocking issue is resolved, even if the numeric score passes

## Scoring

Each category is scored `0` to `2`.

- `0`: inaccessible, confusing, or missing
- `1`: partially usable, but still likely to block or confuse some users
- `2`: clear, accessible, and appropriate for broad user comprehension

## Categories

### 1. Plain-Language Clarity

- Uses short, direct sentences.
- Avoids jargon unless the term is explained in context.
- States what the feature or instruction is for in plain language.

### 2. Technical-Proficiency Inclusiveness

- Assumes the user may not know platform, legal, or technical vocabulary.
- Explains required concepts before asking for an action.
- Does not force advanced knowledge to complete a basic task.

### 3. Task Orientation And Next Step Guidance

- Tells the user what to do now.
- Tells the user what happens next.
- Includes recovery guidance when something fails or needs follow-up.

### 4. Accessible UI Integration

- Labels, hints, and errors are programmatically associated with the correct control.
- Instructions are not conveyed only by color, position, or placeholder text.
- Status changes are announced accessibly when relevant.

### 5. Error Recovery And User Agency

- Errors explain how to recover.
- Wording supports consent, choice, and user control.
- Safety-sensitive flows avoid coercive or punitive default language.

### 6. Visual And Responsive Accessibility

- Meets WCAG 2.1 AA contrast and focus expectations.
- Help text remains readable on mobile and does not overlap controls.
- Important instructions stay visible without requiring hover-only behavior.

### 7. Localization Readiness

- Avoids idioms, abbreviations, and ambiguous shorthand.
- Avoids copy patterns that are hard to translate cleanly.
- Uses stable sentence structure for internationalization.

### 8. Values And Safety Alignment

- Reflects care, accountability, and user dignity.
- Avoids blame-first wording in reporting, moderation, and support flows.
- Makes room for restorative and protective outcomes without forcing either.

## Reviewer Checklist

- Can a first-time, low-technical-proficiency user understand what this is for?
- Can a keyboard-only user complete the task?
- Can a screen-reader user access labels, hints, and errors in order?
- Does the UI explain consequences and next steps clearly?
- Does the copy preserve agency, especially in safety-sensitive flows?
- Would this still make sense after translation?

## Automation Boundary

Automation can reliably help with:

- axe-core accessibility violations
- presence of labels, hints, and structural relationships
- broken heading and link structure in docs
- stale file-path references in documentation

Automation cannot fully judge:

- whether copy is humane, calm, and non-coercive
- whether task guidance is complete for a low-technical-proficiency user
- whether restorative and safety language aligns with BTS values

Those require human review in addition to automated checks.
