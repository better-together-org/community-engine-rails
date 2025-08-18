# frozen_string_literal: true

module BetterTogether
  # Prevents deleting important built-in seed data like default pages
  module Protected
    extend ActiveSupport::Concern

    included do
      validates :protected, inclusion: { in: [true, false] }

      before_destroy do
        if protected?
          errors.add(:base, I18n.t('errors.models.protected_destroy'))
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
