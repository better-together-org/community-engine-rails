#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec/dummy/config/environment'

result = BetterTogether::PersonAssociationAudit.call
issues_found = false

if result[:missing_manifest_entries].any?
  issues_found = true
  warn 'Missing manifest entries:'
  result[:missing_manifest_entries].each do |entry|
    warn "  - #{entry[:key]}"
  end
end

if result[:stale_manifest_entries].any?
  issues_found = true
  warn 'Stale manifest entries:'
  result[:stale_manifest_entries].each do |entry|
    warn "  - #{entry.fetch('key')}"
  end
end

if result[:missing_reverse_associations].any?
  issues_found = true
  warn 'Missing reverse associations:'
  result[:missing_reverse_associations].each do |entry|
    warn "  - #{entry.fetch('owner')}##{entry.fetch('reverse_association')} for #{entry.fetch('key')}"
  end
end

puts 'Person/user association audit passed.' unless issues_found
exit(issues_found ? 1 : 0)
