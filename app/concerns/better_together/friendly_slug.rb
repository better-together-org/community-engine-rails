
module BetterTogether
  module FriendlySlug
    extend ActiveSupport::Concern

    included do
      # extend Mobility
      extend ::FriendlyId
      # translates :slug

      # This method must be called or the class will have validation issues
      def self.slugged(attribute, **options)
        # options = { use: %i[slugged history mobility], **options }
        options = { use: %i[slugged history], **options }

        friendly_id(
          attribute,
          **options
        )

        slug_column = options[:slug_column] || :slug

        validates slug_column, presence: true, uniqueness: true, length: { minimum: 3 }
      end
    end
  end
end
