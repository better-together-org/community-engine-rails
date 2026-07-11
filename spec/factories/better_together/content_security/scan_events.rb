# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/content_security/scan_event',
          class: 'BetterTogether::ContentSecurity::ScanEvent',
          aliases: %i[content_security_scan_event] do
    association :item, factory: :content_security_item
    status { 'completed' }
    plane { 'technical' }
    scanner_name { 'clamav' }
    scanner_version { 'ClamAV 1.0.0' }
    started_at { Time.current }
    finished_at { Time.current }
    verdict { 'clean' }
  end
end
