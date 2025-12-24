# frozen_string_literal: true

# Debug script to test Noticed validation with persisted vs non-persisted objects
require_relative 'spec/dummy/config/environment'

puts '=== TESTING NOTICED WITH NON-PERSISTED MEMBERSHIP ==='
begin
  # Create non-persisted membership like in failing test
  membership = FactoryBot.build(:better_together_person_community_membership, status: 'active')

  # Try to validate with Noticed (mimicking what happens in .with())
  BetterTogether::MembershipCreatedNotifier.with(membership: membership)
  puts 'Non-persisted membership params validation: SUCCESS'
rescue StandardError => e
  puts "Non-persisted membership params validation: FAILED - #{e.message}"
end

puts "\n=== TESTING NOTICED WITH PERSISTED MEMBERSHIP ==="
begin
  # Create persisted membership by saving dependencies first
  platform = FactoryBot.create(:better_together_platform)
  community = FactoryBot.create(:better_together_community, host_platform: platform)
  person = FactoryBot.create(:better_together_person)
  role = FactoryBot.create(:better_together_role)

  # Create persisted membership
  membership = FactoryBot.create(:better_together_person_community_membership,
                                 status: 'active',
                                 joinable: community,
                                 member: person,
                                 role: role)

  # Try to validate with Noticed
  BetterTogether::MembershipCreatedNotifier.with(membership: membership)
  puts 'Persisted membership params validation: SUCCESS'
rescue StandardError => e
  puts "Persisted membership params validation: FAILED - #{e.message}"
end

puts "\n=== COMPARING WITH WORKING JOATU NOTIFIER ==="
begin
  # Test with MatchNotifier that works
  offer = FactoryBot.create(:better_together_joatu_offer)
  request = FactoryBot.create(:better_together_joatu_request)

  BetterTogether::Joatu::MatchNotifier.with(offer: offer, request: request)
  puts 'MatchNotifier params validation: SUCCESS'
rescue StandardError => e
  puts "MatchNotifier params validation: FAILED - #{e.message}"
end
