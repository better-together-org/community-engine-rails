# frozen_string_literal: true

module BetterTogether
  class Upload < ApplicationRecord
    include Creatable
    include Identifier
    include Privacy
    include Translatable

    has_one_attached :file

    delegate :attached?, :byte_size, :content_type, :download, :filename, :url, to: :file

    translates :name
    translates :description, backend: :action_text

    include RemoveableAttachment

    def to_param
      id
    end
  end
end
