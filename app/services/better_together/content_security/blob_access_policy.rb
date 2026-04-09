# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Applies content-security enforcement to shared blob proxy URLs.
    class BlobAccessPolicy
      def self.public_proxy_allowed?(blob)
        new(blob).public_proxy_allowed?
      end

      def initialize(blob)
        @blob = blob
      end

      def public_proxy_allowed?
        return true if subjects.empty?

        subjects.all?(&:publicly_serving_allowed?)
      end

      private

      attr_reader :blob

      def subjects
        @subjects ||= Subject.for_blob(blob).to_a
      end
    end
  end
end
