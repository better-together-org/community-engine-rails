#!/usr/bin/env ruby
# frozen_string_literal: true

# Bulk create system documentation pages from imported diagrams
#
# Usage:
#   bin/dc-run-dummy rails runner docs/examples/bulk_create_system_docs.rb

require 'better_together'

# Map diagram files to documentation pages
SYSTEM_DOCS = {
  'events' => {
    title: 'Events System',
    slug: 'system-events',
    diagrams: %w[
      events_flow.mmd
      events_invitations_flow.mmd
      events_schema_erd.mmd
      events_technical_architecture.mmd
    ],
    intro: <<~MARKDOWN
      # Events System Documentation

      The Events system enables communities to organize gatherings, manage invitations,
      and track attendance.

      ## Key Features

      - Public and private event creation
      - Invitation-based access control
      - RSVP tracking with attendance statuses
      - Email notifications and reminders
      - Location management with privacy controls
    MARKDOWN
  },

  'conversations' => {
    title: 'Conversations & Messaging',
    slug: 'system-conversations',
    diagrams: %w[
      conversations_messaging_flow.mmd
    ],
    intro: <<~MARKDOWN
      # Conversations & Messaging System

      Secure, privacy-respecting messaging between community members.

      ## Features

      - One-on-one conversations
      - Privacy controls (opt-in messaging)
      - Real-time updates via Action Cable
      - Notification integration
      - Message read receipts
    MARKDOWN
  },

  'content' => {
    title: 'Content Management',
    slug: 'system-content',
    diagrams: %w[
      content_flow.mmd
      markdown_content_flow.mmd
      content_schema_erd.mmd
    ],
    intro: <<~MARKDOWN
      # Content Management System

      Flexible, block-based content system with multilingual support.

      ## Architecture

      - Page-based organization
      - Block composition pattern
      - Multiple content types (Markdown, Mermaid, Rich Text)
      - Translation support via Mobility
      - Version control ready
    MARKDOWN
  },

  'metrics' => {
    title: 'Metrics & Analytics',
    slug: 'system-metrics',
    diagrams: %w[
      metrics_flow.mmd
    ],
    intro: <<~MARKDOWN
      # Metrics & Analytics System

      Privacy-first analytics without tracking individual users.

      ## Approach

      - Event-based metrics (no user tracking)
      - Aggregated statistics only
      - Share tracking for content performance
      - Export capabilities for analysis
      - GDPR/privacy compliant by design
    MARKDOWN
  }
}.freeze

def find_diagram(filename)
  BetterTogether::Content::MermaidDiagram.find_by(
    "content_data->>'diagram_file_path' LIKE ?", "%#{filename}"
  )
end

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
def create_system_doc(system_key, config)
  puts "\n📄 Creating #{config[:title]} documentation..."
  # Create or find page
  page = BetterTogether::Page.find_or_initialize_by(slug: config[:slug])
  page.assign_attributes(
    title: config[:title],
    published: true,
    privacy: 'public'
  )

  if page.persisted?
    puts '  ℹ️  Page already exists, clearing blocks...'
    page.page_blocks.destroy_all
  end

  page.save!

  position = 1

  # Add intro
  intro_block = BetterTogether::Content::Markdown.create!(
    markdown_source: config[:intro]
  )
  page.page_blocks.create!(block: intro_block, position: position)
  position += 1
  puts '  ✅ Added introduction'

  # Add diagrams
  config[:diagrams].each do |diagram_filename|
    diagram = find_diagram(diagram_filename)

    if diagram
      page.page_blocks.create!(block: diagram, position: position)
      position += 1
      puts "  ✅ Added diagram: #{diagram_filename}"
    else
      puts "  ⚠️  Diagram not found: #{diagram_filename}"
    end
  end

  # Add closing notes
  notes_block = BetterTogether::Content::Markdown.create!(
    markdown_source: <<~MARKDOWN
      ## Implementation Notes

      This system is part of the Better Together Community Engine.
      For technical implementation details, see the source code and RSpec tests.

      ## Related Systems

      #{related_systems_list(system_key)}
    MARKDOWN
  )
  page.page_blocks.create!(block: notes_block, position: position)
  puts '  ✅ Added implementation notes'

  puts "  🎉 Page created: /en/#{config[:slug]}"
  page
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize

def related_systems_list(current_system)
  SYSTEM_DOCS.keys
             .reject { |k| k == current_system }
             .map { |key| "- [#{SYSTEM_DOCS[key][:title]}](/en/#{SYSTEM_DOCS[key][:slug]})" }
             .join("\n")
end

# Main execution
puts '=' * 80
puts 'BULK SYSTEM DOCUMENTATION CREATOR'
puts '=' * 80

created_pages = []

SYSTEM_DOCS.each do |system_key, config|
  page = create_system_doc(system_key, config)
  created_pages << page
end

puts "\n#{'=' * 80}"
puts "✅ Created #{created_pages.count} system documentation pages"
puts '=' * 80

puts "\nView your documentation:"
created_pages.each do |page|
  puts "  → http://localhost:3000/en/#{page.slug}"
end

puts "\nTo create a documentation index/hub page, run:"
puts '  bin/dc-run-dummy rails runner docs/examples/create_docs_hub.rb'
