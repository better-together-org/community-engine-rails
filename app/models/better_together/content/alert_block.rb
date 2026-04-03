# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a Bootstrap-styled alert panel for announcements and notices.
    class AlertBlock < Block
      ALERT_LEVELS = %w[info warning success danger].freeze

      store_attributes :content_data do
        alert_level  String, default: 'info'
        heading      String, default: ''
        body_text    String, default: ''
        dismissible  String, default: 'false'
      end

      validates :alert_level, inclusion: { in: ALERT_LEVELS }

      def dismissible?
        dismissible == 'true'
      end

      def self.content_addable?
        false
      end

      def self.extra_permitted_attributes
        super + %i[alert_level heading body_text dismissible]
      end
    end
  end
end
