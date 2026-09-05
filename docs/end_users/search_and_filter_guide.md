# Search and Filter Guide

**Target Audience:** Community members  
**Document Type:** User Guide  
**Last Updated:** March 2026

## Overview

In the current `0.11.0` worktree, Community Engine gives you two main ways to find content:

- the shared search bar for site-wide keyword search
- the events index, which groups events by timing

This guide only covers behavior that exists on this branch today.

## Site-wide search

The shared search form submits a `GET` request to `/search` with a `q` parameter.

What to expect:

- results are shown 10 at a time
- suggestions may appear when the search backend can offer close matches
- empty searches open the results page without recording a search query metric
- search failures do not show a crash page; the app still renders the search screen

## What search currently includes

The current global search registry indexes:

- pages
- posts

In practice, this means:

- post titles and post body content can appear in results
- page titles and indexed page block content can appear in results
- events are **not** part of the current global Elasticsearch registry on this branch

## Searching for posts

Posts are the main user-facing content type currently covered by the search index.

Tips:

- search for distinctive words from a post title first
- if that does not work, search for a phrase from the post body
- try a shorter keyword if the first query returns no results
- use suggestion links when the page offers a close spelling match

## Browsing events

Events are currently discovered through the events index rather than the site-wide search registry.

The events index groups records into these sections:

- **Draft**: no `starts_at` value yet
- **Upcoming**: starts in the future
- **Ongoing**: already started and not yet ended
- **Past**: already finished

Public visitors only see events that are visible through the current event privacy rules. If you have a host role, attendance relationship, or invitation token, you may be able to see more than the public list.

## Current limitations on this branch

The changelog mentions richer posts and events filter forms, but this worktree does not currently include a user-facing sidebar filter form for either content type.

Today, the practical workflow is:

- use `/search` to find pages and posts by keyword
- use `/events` to browse events by timing
- open the item itself to review categories, privacy context, and next actions

## Related guides

- [Events system](../developers/systems/events_system.md)
- [Reporting Harm and Safety Concerns](reporting_harm_and_safety_concerns.md)
- [0.11.0 Release Overview](../releases/0.11.0.md)
