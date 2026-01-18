# frozen_string_literal: true

# Example: Creating Documentation Pages with Diagram File Paths

require 'better_together'

# This script demonstrates how to use diagram_file_path to build documentation pages

# Step 1: Import all diagrams (one-time setup)
puts 'Step 1: Importing diagrams...'
system('bin/dc-run-dummy rake better_together:content:import_diagrams')

# Step 2: Find imported diagrams
puts "\nStep 2: Finding imported diagrams..."
events_flow = BetterTogether::Content::MermaidDiagram.find_by(
  "content_data->>'diagram_file_path' LIKE ?", '%events_flow.mmd'
)

BetterTogether::Content::MermaidDiagram.find_by(
  "content_data->>'diagram_file_path' LIKE ?", '%conversations_messaging_flow.mmd'
)

# Step 3: Create documentation page
puts "\nStep 3: Creating Events documentation page..."
events_page = BetterTogether::Page.create!(
  title: 'Events System Documentation',
  slug: 'events-documentation',
  published: true,
  privacy: 'public'
)

# Step 4: Add intro text
intro = BetterTogether::Content::Markdown.create!(
  markdown_source: <<~MARKDOWN
    # Events System Documentation

    This page documents the Better Together Events system architecture and workflows.

    ## Overview

    The Events system allows communities to organize gatherings, send invitations,#{' '}
    and track RSVPs. The following diagrams illustrate key processes and data flows.
  MARKDOWN
)
events_page.page_blocks.create!(block: intro, position: 1)

# Step 5: Add event flow diagram
if events_flow
  events_page.page_blocks.create!(
    block: events_flow,
    position: 2
  )
  puts '  ✅ Added Events Flow diagram'
end

# Step 6: Add more documentation
technical_details = BetterTogether::Content::Markdown.create!(
  markdown_source: <<~MARKDOWN
    ## Technical Details

    ### Key Models

    - `Event` - Core event model with date/time, location, description
    - `EventAttendance` - Tracks RSVPs and attendance status
    - `EventInvitation` - Manages invitation tokens and privacy

    ### Access Control

    Events use Pundit policies to enforce access control based on:
    - Event privacy settings (public/private/community-only)
    - User membership in event communities
    - Invitation tokens for private events
  MARKDOWN
)
events_page.page_blocks.create!(block: technical_details, position: 3)

puts "\n✅ Created Events documentation page at /en/events-documentation"
puts "\nYou can view it by visiting:"
puts '  http://localhost:3000/en/events-documentation'
