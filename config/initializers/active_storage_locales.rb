# frozen_string_literal: true

# Extend ActiveStorage::Attachment with a locale attribute helpers
Rails.application.config.to_prepare do
  ActiveSupport.on_load(:active_storage_attachment) do
    # ensure presence of locale is validated at model level as well
    unless method_defined?(:locale)
      # The migration will add locale column. Guard so this file can be loaded pre-migration.
      define_method(:locale) { read_attribute(:locale) if respond_to?(:read_attribute) }
    end

    include Module.new do
      def self.included(base)
        base.class_eval do
          validates :locale, presence: true

          scope :for_locale, ->(locale) { where(locale: locale.to_s) }

          before_validation :set_locale, on: :create

          def set_locale
            return if locale.present?

            self.locale = I18n.locale
          end
        end
      end
    end
  end
end
