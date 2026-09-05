# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/content_security/finding',
          class: 'BetterTogether::ContentSecurity::Finding',
          aliases: %i[content_security_finding] do
    association :item, factory: :content_security_item
    association :scan_event, factory: :content_security_scan_event

    plane { 'technical' }
    finding_type { 'malware_signature' }
    rule_id { "Eicar-Test-Signature-#{SecureRandom.hex(4)}" }
    severity { 'high' }
    confidence { 'high' }
    verdict { 'quarantined' }
    evidence_summary { 'Malware signature detected during upload scanning: Eicar-Test-Signature' }
    detected_at { Time.current }

    trait :scan_failure do
      finding_type { 'scan_failure' }
      severity { 'medium' }
      verdict { 'review_required' }
      evidence_summary { 'Malware scanning failed and the upload is being held for review.' }
    end
  end
end
