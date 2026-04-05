# frozen_string_literal: true

module BetterTogether
  # Creates a private draft page + post pair for release package editing.
  class ReleasePackageDraftBuilder
    Result = Data.define(:page, :post)

    DEFAULT_POST_CONTENT = <<~CONTENT
      This is a private draft release package announcement.

      Review and edit this post before publication.
    CONTENT

    def initialize(creator:, title:, robot_author_ids: [])
      @creator = creator
      @title = title
      @robot_author_ids = Array(robot_author_ids).reject(&:blank?)
    end

    def call
      BetterTogether::Authorship.with_creator(creator) do
        ActiveRecord::Base.transaction do
          page = build_page!
          post = build_post!

          Result.new(page, post)
        end
      end
    end

    private

    attr_reader :creator, :title, :robot_author_ids

    def build_page!
      BetterTogether::Page.create!(
        title:,
        privacy: 'private',
        published_at: nil,
        creator: creator,
        author_ids: [creator.id],
        robot_author_ids:
      )
    end

    def build_post!
      BetterTogether::Post.create!(
        title:,
        privacy: 'private',
        published_at: nil,
        content: DEFAULT_POST_CONTENT,
        creator: creator,
        author_ids: [creator.id],
        robot_author_ids:
      )
    end
  end
end
