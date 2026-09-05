# Personal Data Export Guide

This guide explains the self-service personal data export flow that currently exists in Community Engine `0.11.0`.

## Who can use it

The export flow is for signed-in users with an associated person record. The UI lives under:

- `/my/seeds`

## What the export does

When you request an export, Community Engine creates a personal `Seed` record for your person profile. That export can then be:

- viewed in the browser
- downloaded as a YAML file
- deleted later from the same screen

The export list also shows metadata such as the export identifier, version, description, and creation time.

## How to request an export

1. open the "My Seeds" page
2. choose the button to create a new export
3. return to the export list after the request completes
4. open the export you want to inspect or download

## Downloading the YAML file

On the export detail page, use the download button to retrieve the attached YAML file.

The detail page also shows:

- seed metadata
- origin data
- payload data
- any recorded planting history attached to that export

## Rate limit

The current branch enforces a one-hour cooldown between personal exports for the same person. If you request another export too soon, the system will keep the existing export list and show an error message instead of creating a new one immediately.

## Deleting an export

You can delete your own personal export from the detail page. Deleting the export removes that stored export record; it does not delete your account or your underlying platform data.

## What this feature is not

This feature is not a public sharing link and it is not an external API. It is a signed-in self-service export flow tied to your own account.

If you need help finding the page or understanding the file, contact your platform support team or organizers.
