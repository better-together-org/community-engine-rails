# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_citation, class: 'BetterTogether::Citation', aliases: [:citation] do
    association :citeable, factory: :better_together_post
    title { 'Community Evidence Report' }
    source_kind { 'webpage' }
    source_author { 'Better Together Research Circle' }
    publisher { 'Better Together' }
    published_on { Date.new(2026, 4, 4) }
    accessed_on { Date.new(2026, 4, 4) }
    source_url { 'https://example.org/evidence-report' }
    reference_key { 'community_evidence_report' }
    locator { 'p. 14' }
    excerpt { 'Evidence should remain traceable across contribution and publication flows.' }
  end
end
