# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_claim, class: 'BetterTogether::Claim', aliases: [:claim] do
    association :claimable, factory: :better_together_post
    claim_key { 'shared_reality_claim' }
    statement { 'Shared reality needs evidence chains that remain auditable over time.' }
    selector { 'paragraph:1' }
    review_status { 'draft' }
  end
end
