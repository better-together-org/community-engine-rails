# frozen_string_literal: true

require 'mobility/backend'

module Mobility
  module Backends
    # Mobility backend for localized attachments using ActiveStorage::Attachment with locale column
    module Attachments
      extend ActiveSupport::Concern

      class_methods do
        def valid_keys
          [:fallback]
        end

        def setup(&)
          # this method is required by Mobility backend pattern; actual setup is performed in configure
          super if defined?(super)
        end
      end

      # Called by Mobility when including backend on a model
      def self.setup
        # placeholder for compatibility
      end
    end
  end
end
