# frozen_string_literal: true

module BetterTogether
  # Reverse associations for records explicitly created by a person.
  module CreatedRecords
    extend ActiveSupport::Concern

    included do
      has_many :created_authorships,
               foreign_key: :creator_id,
               class_name: 'BetterTogether::Authorship',
               inverse_of: :creator
      has_many :created_pages,
               foreign_key: :creator_id,
               class_name: 'BetterTogether::Page',
               inverse_of: :creator
      has_many :created_wizard_steps,
               foreign_key: :creator_id,
               class_name: 'BetterTogether::WizardStep',
               inverse_of: :creator
      has_many :created_communities,
               foreign_key: :creator_id,
               class_name: 'BetterTogether::Community',
               inverse_of: :creator
    end
  end
end
