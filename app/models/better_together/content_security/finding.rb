# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Persists a single malware-scan finding (virus signature or scanner error) for an Item.
    class Finding < ApplicationRecord
      self.table_name = 'better_together_content_security_findings'

      include BetterTogether::PlatformScoped

      belongs_to :item, class_name: 'BetterTogether::ContentSecurity::Item', inverse_of: :findings
      belongs_to :scan_event, class_name: 'BetterTogether::ContentSecurity::ScanEvent', inverse_of: :findings
      belongs_to :safety_case, class_name: 'BetterTogether::Safety::Case', optional: true

      validates :plane, :finding_type, :severity, :confidence, :verdict, :detected_at, presence: true
    end
  end
end
