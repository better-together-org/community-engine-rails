# frozen_string_literal: true

module BetterTogether
  module Categorizable # rubocop:todo Style/Documentation
    extend ::ActiveSupport::Concern

    included do
      class_attribute :category_class_name, default: '::BetterTogether::Category'
      class_attribute :extra_category_permitted_attributes, default: []
    end

    class_methods do
      # Safe allow-list of category classes used in the engine
      def allowed_category_classes
        %w[
          BetterTogether::Category
          BetterTogether::EventCategory
          BetterTogether::Joatu::Category
        ]
      end

      # Resolve the category class via SafeClassResolver
      def category_klass
        BetterTogether::SafeClassResolver.resolve!(category_class_name, allowed: allowed_category_classes)
      end

      def categorizable(class_name: category_class_name) # rubocop:todo Metrics/MethodLength
        self.category_class_name = class_name

        has_many :categorizations, class_name: 'BetterTogether::Categorization', as: :categorizable,
                                   dependent: :destroy,
                                   autosave: true
        has_many :categories, through: :categorizations, source_type: category_class_name do
          def with_cover_images # rubocop:todo Lint/NestedMethodDefinition
            left_joins(:cover_image_attachment).where.not(active_storage_attachments: { id: nil })
          end
        end

        # Add the permitted attributes for this method dynamically
        self.extra_category_permitted_attributes += [{ category_ids: [] }]

        define_method :cache_key do
          "#{super()}/categories-#{category_ids.size}"
        end
      end

      def extra_permitted_attributes
        super + extra_category_permitted_attributes
      end
    end
  end
end
