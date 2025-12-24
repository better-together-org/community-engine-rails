# frozen_string_literal: true

# Debug script to check membership serialization
require_relative 'spec/dummy/config/environment'

# Create a test membership
membership = FactoryBot.build(:better_together_person_community_membership, status: 'active')

puts '=== MEMBERSHIP OBJECT DEBUG ==='
puts "Membership class: #{membership.class}"
puts "Membership id: #{membership.id}"
puts "Membership persisted?: #{membership.persisted?}"
puts "Membership new_record?: #{membership.new_record?}"
puts "Membership member: #{membership.member&.class}"
puts "Membership member id: #{membership.member&.id}"
puts "Membership member persisted?: #{membership.member&.persisted?}"

# Try to serialize the membership for Noticed
puts "\n=== SERIALIZATION TESTS ==="
begin
  params_hash = { membership: membership }
  puts "Params hash: #{params_hash}"
  puts "Membership serializable?: #{membership.class.respond_to?(:serialize)}"

  # Check if membership can be converted to global ID
  if membership.respond_to?(:to_global_id)
    puts "Membership global_id: #{membership.to_global_id}"
  else
    puts 'Membership does NOT respond to to_global_id'
  end

  # Check if membership is nil or falsey
  puts "Membership present?: #{membership.present?}"
  puts "Membership nil?: #{membership.nil?}"
  puts "Membership blank?: #{membership.blank?}"
rescue StandardError => e
  puts "Error during serialization test: #{e.message}"
end

# Compare with a persisted membership
puts "\n=== PERSISTED MEMBERSHIP TEST ==="
begin
  persisted_membership = FactoryBot.create(:better_together_person_community_membership, status: 'active')
  puts "Persisted membership id: #{persisted_membership.id}"
  puts "Persisted membership persisted?: #{persisted_membership.persisted?}"

  if persisted_membership.respond_to?(:to_global_id)
    puts "Persisted membership global_id: #{persisted_membership.to_global_id}"
  else
    puts 'Persisted membership does NOT respond to to_global_id'
  end
rescue StandardError => e
  puts "Error creating persisted membership: #{e.message}"
end

puts "\n=== OFFER COMPARISON ==="
# Create a test offer for comparison
begin
  offer = FactoryBot.create(:better_together_joatu_offer)
  puts "Offer class: #{offer.class}"
  puts "Offer persisted?: #{offer.persisted?}"
  puts "Offer global_id: #{offer.to_global_id}"
rescue StandardError => e
  puts "Error creating offer: #{e.message}"
end
