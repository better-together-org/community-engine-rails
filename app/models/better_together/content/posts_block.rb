# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a collection of BetterTogether::Post records
    class PostsBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes

      POSTS_SCOPES = %w[published all].freeze

      store_attributes :content_data do
        posts_scope String, default: 'published'
      end

      validates :posts_scope, inclusion: { in: POSTS_SCOPES }

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[posts_scope]
      end
    end
  end
end
