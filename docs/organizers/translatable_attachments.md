## Translatable Attachments — Organizer Guide

Purpose
-------

Organizers can upload images or files that are specific to a language or
locale. The translatable attachments feature stores one attachment per locale
so you can present localized media to your users.

How to use
----------

When editing content in the admin interface, you'll see a tabbed file upload
field labelled by language (for example, "English", "Français"). Upload a
file in each tab to provide localized media.

Behavior
--------

- The site will use the file for the requested locale if present.
- If a file for the requested locale is not present, the system may fall back
  to the default language's file (this is configurable by developers).
- When you remove a file from a locale, that locale-specific attachment will
  be deleted; other locales are unaffected.

Best practices
--------------

- Provide translations for alt text and captions to match the localized
  media — the attachment itself is just the binary file.
- Keep file sizes optimized for the web; large images slow down page loads.

Troubleshooting
---------------

- If you don't see the language tabs, ensure you have appropriate
  permissions and that your organization has multiple locales enabled.
- If uploads fail, check file type restrictions (some admins forbid certain
  file types) and contact the technical team.
