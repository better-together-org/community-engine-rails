# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_evidence_link, class: 'BetterTogether::EvidenceLink', aliases: [:evidence_link] do
    association :claim, factory: :better_together_claim
    association :citation, factory: :better_together_citation
    relation_type { 'supports' }
    locator { 'p. 17' }
    quoted_text { 'Evidence and claims should remain linked in the published record.' }
    review_status { 'draft' }
  end
end
