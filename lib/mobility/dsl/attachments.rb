# frozen_string_literal: true

# Mobility Attachments DSL
#
# Provides a small, explicit DSL for applying localized attachment accessors
# to models at class-definition time. Use this when you need the meta-generated
# accessors to exist immediately (for example in test bootstraps, engines, or
# other early-loading contexts). Prefer calling Mobility's standard
# `translates :attr, backend: :attachments` when the backend registration is
# available early in the boot process.
#
# Examples
#
#   class Page < ApplicationRecord
#     extend Mobility::DSL::Attachments
#
#     # create per-locale accessors for :hero_image using the attachments backend
#     translates_attached :hero_image, content_type: [/image/] , presence: true
#   end
#
module Mobility
  module DSL
    # Small DSL module that exposes `translates_attached` for immediate
    # application of the attachments backend at class-definition time.
    module Attachments
      # Apply localized attachment accessors to the model class.
      # Accepts the same attribute list and options as the underlying
      # AttachmentsBackend.apply_to method. Supported options include
      # :content_type and :presence (see backend implementation for details).
      def translates_attached(*attributes, **options)
        require 'mobility/backends/attachments/backend'
        Mobility::Backends::AttachmentsBackend.apply_to(self, attributes, options)
      end
    end
  end
end
