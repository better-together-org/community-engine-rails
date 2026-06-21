#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../spec/dummy/config/environment'

options = {
  person_ids: [],
  user_ids: [],
  emails: [],
  execute: false
}

OptionParser.new do |parser|
  parser.banner = 'Usage: bundle exec ruby scripts/person_hard_delete.rb [options]'

  parser.on('--person-id ID', 'Target a BetterTogether::Person by UUID') { |value| options[:person_ids] << value }
  parser.on('--user-id ID', 'Target a BetterTogether::User by UUID') { |value| options[:user_ids] << value }
  parser.on('--email EMAIL', 'Target a BetterTogether::User by email') { |value| options[:emails] << value }
  parser.on('--reviewed-by-person-id ID', 'Reviewer person UUID for audit logging') { |value| options[:reviewed_by_person_id] = value }
  parser.on('--reason TEXT', 'Reason recorded in the purge audit snapshot') { |value| options[:reason] = value }
  parser.on('--execute', 'Execute the hard delete instead of dry-run inventory output') { options[:execute] = true }
end.parse!

reviewed_by = if options[:reviewed_by_person_id].present?
                BetterTogether::Person.find(options[:reviewed_by_person_id])
              end

target_people = []
target_people.concat(BetterTogether::Person.where(id: options[:person_ids]).to_a) if options[:person_ids].any?

if options[:user_ids].any?
  BetterTogether::User.where(id: options[:user_ids]).includes(:person).find_each do |user|
    target_people << user.person if user.person
  end
end

if options[:emails].any?
  BetterTogether::User.where(email: options[:emails]).includes(:person).find_each do |user|
    target_people << user.person if user.person
  end
end

target_people = target_people.compact.uniq(&:id)

if target_people.empty?
  warn 'No target people found. Provide at least one --person-id, --user-id, or --email.'
  exit 1
end

results = target_people.map do |person|
  if options[:execute]
    audit = BetterTogether::PersonHardDeletionExecutor.call(
      person:,
      reviewed_by:,
      reason: options[:reason]
    )

    {
      person_id: person.id,
      status: audit.status,
      audit_id: audit.id,
      execution_snapshot: audit.execution_snapshot
    }
  else
    BetterTogether::PersonHardDeletionInventory.call(person:)
  end
end

puts JSON.pretty_generate(results)
