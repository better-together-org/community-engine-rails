# frozen_string_literal: true

module BetterTogether
  # Prevents deleting important built-in seed data like default pages
  module Protected
    extend ActiveSupport::Concern

    included do
      validates :protected, inclusion: { in: [true, false] }

      before_destroy do
        if protected?
          errors.add(:base, 'This record is protected and cannot be destroyed.')
          throw(:abort)
        end
      end

      scope :only_protected, -> { where(protected: true) }
    end

    def protected?
      protected
    end
  end
end
