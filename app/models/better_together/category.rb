module BetterTogether
  class Category < ApplicationRecord
    include Identifier
    include Positioned
    include Protected
    include Translatable

    has_many :categorizations, dependent: :destroy
    has_many :pages, through: :categorizations, source: :categorizable, source_type: 'BetterTogether::Page'

    translates :name, type: :string
    translates :description, backend: :action_text

    validates :name, presence: true
    validates :type, presence: true

    def to_s
      name
    end
  end
end
