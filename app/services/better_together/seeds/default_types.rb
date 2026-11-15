# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength, Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength

module BetterTogether
  module Seeds
    # Core Community Engine types available to every packet.
    module DefaultTypes
      def self.register_all
        register_content
        register_navigation
        register_files_and_events
        register_contacts
        register_redirects
      end

      def self.register_content
        Registry.register(:page) do
          model 'BetterTogether::Page'
          attributes :slug, :privacy, :meta_description, :keywords, :layout, :template, :published_at, :show_title
          protectable
          translated :title, :content
          reference :community, to: :community, optional: true
          reference :sidebar_nav, to: :navigation_area, optional: true
        end
        Registry.register(:content_block) do
          model 'BetterTogether::Content::Block'
          sti :type, allowed: -> { BetterTogether::Seeds::DefaultTypes.content_block_types }
          attributes :privacy, :visible, :css_settings, :html_attributes, :content_data, :media_settings, :template_path
          translated :content
          attachment :background_image_file
        end
        Registry.register(:page_block) do
          model 'BetterTogether::Content::PageBlock'
          natural_key by_refs: %i[page block]
          reference :page, to: :page
          reference :block, to: :content_block
          position :position
        end
      end

      # Block subclasses are autoloaded, so load them before asking for descendants (outside eager-load
      # environments the list is otherwise empty).
      def self.content_block_types
        Rails.autoloaders.main.eager_load_dir(BetterTogether::Engine.root.join('app/models/better_together/content').to_s)
        BetterTogether::Content::Block.descendants.map(&:name)
      end

      def self.register_navigation
        Registry.register(:navigation_area) do
          model 'BetterTogether::NavigationArea'
          attributes :visible, :style
          protectable
          translated :name
        end
        Registry.register(:navigation_item) do
          model 'BetterTogether::NavigationItem'
          attributes :item_type, :url, :icon, :route_name, :visible, :privacy, :visibility_strategy,
                     :permission_identifier
          protectable
          translated :title
          reference :navigation_area, to: :navigation_area
          reference :parent, to: :navigation_item, optional: true
          reference :linkable, to: %i[page community], optional: true
          position :position
        end
      end

      def self.register_files_and_events
        Registry.register(:upload) do
          model 'BetterTogether::Upload'
          attributes :privacy
          translated :name, :description
          attachment :file
        end
        Registry.register(:event) do
          model 'BetterTogether::Event'
          attributes :privacy, :starts_at, :ends_at, :duration_minutes, :timezone, :registration_url, :status
          translated :name, :description
          attachment :cover_image
          # Events need a host; seeds have no creator, so the target platform's community hosts them.
          before_save do |event, platform|
            event.event_hosts.build(host: platform.community) if event.event_hosts.empty? && platform.community
          end
        end
      end

      def self.register_contacts
        Registry.register(:community) do
          model 'BetterTogether::Community'
          attributes :privacy
          translated :name, :description
          attachment :cover_image
          attachment :logo
        end
        Registry.register(:contact_detail) do
          model 'BetterTogether::ContactDetail'
          natural_key :name, within: :contactable
          attributes :role
          reference :contactable, to: %i[community platform]
        end
        Registry.register(:social_media_account) do
          model 'BetterTogether::SocialMediaAccount'
          natural_key :platform_name, within: :contact_detail
          attributes :platform_name, :handle, :url, :privacy
          reference :contact_detail, to: :contact_detail
        end
        Registry.register(:platform) do
          model 'BetterTogether::Platform'
          platform_column nil
          attributes :time_zone, :host_url
          translated :name, :description
          attachment :profile_image
          attachment :cover_image
        end
      end

      # Redirects are matched on from_path (an attribute, since a URL path is not a valid packet key),
      # unique per platform.
      def self.register_redirects
        Registry.register(:redirect) do
          model 'BetterTogether::Redirect'
          natural_key :from_path, via_attribute: true
          attributes :from_path, *BetterTogether::Redirect::SEED_ATTRIBUTES
        end
      end

      private_class_method :register_content, :register_navigation, :register_files_and_events, :register_contacts,
                           :register_redirects
    end
  end
end
# rubocop:enable Metrics/ModuleLength, Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength
