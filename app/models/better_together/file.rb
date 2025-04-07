# frozen_string_literal: true

module BetterTogether
  class File < ApplicationRecord
    include Creatable
    include Identifier
    include Privacy
    include Translatable

    has_one_attached :file

    delegate :attached?, :byte_size, :content_type, :download, :filename, :url, to: :file

    translates :name
    translates :description, backend: :action_text

    # def self.permitted_attributes(id: false, destroy: false)
    #   %i[file] + super
    # end

    include RemoveableAttachment
  end
end
