# frozen_string_literal: true

module BetterTogether
  module Content
    # Collections and cache fingerprints for blocks that render live records (posts, events, people, communities,
    # a checklist, a navigation area, a gallery, a download). Any cache around such a block, including the page's,
    # keys on #dynamic_block_cache_stamp so it follows the data instead of freezing at the last page edit.
    module RecordBlocksHelper
      include BetterTogether::MediaCacheContextHelper

      # Who is looking, as far as record visibility goes, so cached output is never shared across viewers who can
      # see different records.
      def page_visibility_cache_context
        return send(:nav_permission_cache_stamp) if respond_to?(:nav_permission_cache_stamp, true)

        current_user&.cache_key_with_version || 'guest'
      end

      # Blocks that render a live collection of records, mapped to what they list. Anything cached around such a
      # block (the page, the block itself) must key on what the collection holds now, so a block added here is
      # picked up by every cache key through #dynamic_block_cache_stamp.
      def record_block_collection(block)
        case block
        when BetterTogether::Content::EventsBlock then event_block_collection(block)
        when BetterTogether::Content::PostsBlock then post_block_collection(block)
        when BetterTogether::Content::PeopleBlock
          resource_block_collection(block, BetterTogether::Person, extra_scope: ->(s) { s.order(created_at: :desc) })
        when BetterTogether::Content::CommunitiesBlock
          resource_block_collection(block, BetterTogether::Community,
                                    extra_scope: ->(s) { s.order(created_at: :desc) })
        end
      end

      # A fingerprint of the records +block+ would render for this viewer, or nil for blocks that show no live
      # records. It changes when a record is added, edited, removed, hidden from the viewer, or leaves a time
      # window such as "upcoming". Every cache that wraps such a block (the block's own, the page's) keys on it.
      def dynamic_block_cache_stamp(block)
        parts = if (collection = record_block_collection(block))
                  collection_parts(block, collection)
                else
                  linked_record_fingerprint(block)
                end
        return if parts.nil?

        [block.class.name, block.id, parts, page_visibility_cache_context, media_url_cache_context]
      end

      def collection_parts(block, collection)
        parts = [collection_fingerprint(collection)]
        parts << post_card_fingerprint(collection) if block.is_a?(BetterTogether::Content::PostsBlock)
        parts
      end

      def collection_fingerprint(collection)
        table = collection.klass.arel_table
        rows = collection.pluck(table[:id], table[:updated_at])
        Digest::SHA1.hexdigest(rows.map { |id, at| "#{id}:#{at.to_f}" }.join(','))
      end

      # What a post card draws besides the post itself: its community's mark, its categories (the first one with a
      # cover image stands in for a missing post cover) and its contributors' avatars. Attaching or replacing an
      # image touches the record that owns it, so these versions change when any of those images does.
      def post_card_fingerprint(collection)
        posts = collection.includes(:community, :categories, contributions: :author).to_a
        versions = posts.flat_map do |post|
          [post.community, *post.categories, *post.contributions.map(&:author)].compact.map(&:cache_key_with_version)
        end
        Digest::SHA1.hexdigest(versions.join(','))
      end

      # Blocks that render one chosen record and its children (a checklist and its items, a navigation area and
      # its items, a gallery's images, a downloadable upload). Counts catch deletions that no timestamp shows.
      def linked_record_fingerprint(block)
        case block
        when BetterTogether::Content::ChecklistBlock then checklist_fingerprint(block.checklist)
        when BetterTogether::Content::NavigationAreaBlock then navigation_area_fingerprint(block.navigation_area)
        when BetterTogether::Content::ImageGalleryBlock then gallery_fingerprint(block)
        when BetterTogether::Content::FileDownloadBlock then upload_fingerprint(block.upload)
        end
      end

      def checklist_fingerprint(checklist)
        checklist && [checklist.cache_key_with_version, child_stamp(checklist.checklist_items)]
      end

      def navigation_area_fingerprint(area)
        area && [area.cache_key_with_version, child_stamp(area.navigation_items)]
      end

      def gallery_fingerprint(block)
        block.images.select { |image| image.media.attached? && policy(image).show? }.map(&:cache_key_with_version)
      end

      def upload_fingerprint(upload)
        upload && [upload.cache_key_with_version, policy(upload).download?]
      end

      def child_stamp(relation)
        [relation.count, relation.maximum(:updated_at)&.to_f]
      end

      def event_block_collection(block)
        starts_at = BetterTogether::Event.arel_table[:starts_at]
        order_scope = case block.event_scope
                      when 'upcoming' then ->(s) { s.where(starts_at.gteq(Time.current)).reorder(starts_at: :asc) }
                      when 'recent'   then ->(s) { s.where(starts_at.lt(Time.current)).reorder(starts_at: :desc) }
                      else                 ->(s) { s.reorder(starts_at: :desc) }
                      end
        resource_block_collection(block, BetterTogether::Event, extra_scope: order_scope)
      end

      def post_block_collection(block)
        order_scope = if block.posts_scope == 'published'
                        ->(s) { s.where.not(published_at: nil).order(published_at: :desc) }
                      else
                        ->(s) { s.order(created_at: :desc) }
                      end
        resource_block_collection(block, BetterTogether::Post, extra_scope: order_scope)
      end
    end
  end
end
