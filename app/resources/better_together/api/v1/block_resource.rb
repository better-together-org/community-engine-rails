# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Content::Block (all STI types)
      #
      # Exposes the full block attribute surface for headless CMS operations.
      # Blocks are identified by their UUID and their concrete type is exposed
      # via the `block_type` attribute (e.g. "BetterTogether::Content::AccordionBlock").
      #
      # Translatable attributes (Markdown, Hero, Image, Css, Html, MermaidDiagram)
      # are exposed via locale-suffixed attributes (e.g. markdown_source_en, heading_fr).
      #
      # Storext content_data attributes (accordion_items_json, alert_level, video_url, etc.)
      # are exposed as flat attributes. Writes go through `block_params` in the controller
      # which uses `extra_permitted_attributes` for whitelisting.
      #
      # Position on a page is managed via the PageBlock join — use the page_blocks endpoint
      # or the page update endpoint (page_blocks_attributes) for ordering.
      # rubocop:disable Metrics/ClassLength
      class BlockResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Content::Block'

        # ── Core identity ────────────────────────────────────────────────────────
        # :type is a JSONAPI reserved keyword — expose STI discriminator as :block_type instead
        attribute :block_type do
          @model.type
        end
        attributes :identifier, :privacy, :visible, :protected

        # Computed label describing the block type (demodulized underscored)
        attribute :block_name do
          @model.block_name
        end

        # ── Storext content_data attrs (all STI subtypes, guarded) ──────────────
        # Each subtype only defines the Storext attrs it uses. Calling an attr that
        # a given subtype doesn't define raises NoMethodError. Use respond_to? guards
        # so that serializing any block type returns nil for attrs it doesn't own.
        def self.safe_attribute(*names)
          names.each do |name|
            attribute(name) { @model.respond_to?(name) ? @model.public_send(name) : nil }
          end
        end

        safe_attribute :heading, :accordion_items_json, :open_first,
                       :alert_level, :body_text, :dismissible,
                       :subheading, :primary_button_label, :primary_button_url,
                       :secondary_button_label, :secondary_button_url, :layout,
                       :quote_text, :attribution_name, :attribution_title, :attribution_organization,
                       :stats_json, :columns,
                       :video_url, :caption, :aspect_ratio,
                       :display_style, :item_limit, :show_view_more_link, :view_more_url,
                       :community_scope_id, :resource_ids,
                       :event_scope, :posts_scope,
                       :checklist_id, :navigation_area_id,
                       :template_path,
                       :diagram_source, :theme, :auto_height,
                       :markdown_file_path, :auto_sync_from_file,
                       :html_content, :cta_url

        # ── Translatable attrs (Mobility — via locale suffix accessors) ──────────
        # Exposed as locale-suffixed attributes, e.g. markdown_source_en
        %w[en fr es uk].each do |locale|
          attribute :"markdown_source_#{locale}" do
            @model.respond_to?(:"markdown_source_#{locale}") ? @model.send(:"markdown_source_#{locale}") : nil
          end
          attribute :"heading_#{locale}" do
            @model.respond_to?(:"heading_#{locale}") ? @model.send(:"heading_#{locale}") : nil
          end
          attribute :"cta_text_#{locale}" do
            @model.respond_to?(:"cta_text_#{locale}") ? @model.send(:"cta_text_#{locale}") : nil
          end
          attribute :"content_#{locale}" do
            @model.respond_to?(:"content_#{locale}") ? @model.send(:"content_#{locale}") : nil
          end
          attribute :"attribution_#{locale}" do
            @model.respond_to?(:"attribution_#{locale}") ? @model.send(:"attribution_#{locale}") : nil
          end
          attribute :"alt_text_#{locale}" do
            @model.respond_to?(:"alt_text_#{locale}") ? @model.send(:"alt_text_#{locale}") : nil
          end
          attribute :"caption_#{locale}" do
            @model.respond_to?(:"caption_#{locale}") ? @model.send(:"caption_#{locale}") : nil
          end
          attribute :"diagram_source_#{locale}" do
            @model.respond_to?(:"diagram_source_#{locale}") ? @model.send(:"diagram_source_#{locale}") : nil
          end
        end

        # ── Associations ─────────────────────────────────────────────────────────
        has_many :pages
        has_many :page_blocks, class_name: 'PageBlock'
        has_one :creator, class_name: 'Person'

        # ── Filters ──────────────────────────────────────────────────────────────
        filter :block_type, apply: lambda { |records, value, _options|
          classes = Array(value).map { |v| resolve_block_class(v) }.compact
          classes.any? ? records.where(type: classes) : records
        }
        filter :privacy
        filter :identifier

        # Filter blocks by page — supports ?filter[page_id]=<uuid>
        filter :page_id, apply: lambda { |records, value, _options|
          records.joins(:page_blocks).where(
            better_together_content_page_blocks: { page_id: value }
          )
        }

        # ── Field permissions ─────────────────────────────────────────────────────
        def self.creatable_fields(_context) # rubocop:disable Metrics/MethodLength
          %i[
            block_type identifier privacy visible
            heading accordion_items_json open_first
            alert_level body_text dismissible
            subheading primary_button_label primary_button_url
            secondary_button_label secondary_button_url layout
            quote_text attribution_name attribution_title attribution_organization
            stats_json columns
            video_url caption aspect_ratio
            display_style item_limit show_view_more_link view_more_url
            community_scope_id resource_ids event_scope posts_scope
            checklist_id navigation_area_id template_path
            diagram_source theme auto_height markdown_file_path auto_sync_from_file
            html_content cta_url
            markdown_source_en markdown_source_fr markdown_source_es markdown_source_uk
            heading_en heading_fr heading_es heading_uk
            cta_text_en cta_text_fr cta_text_es cta_text_uk
            content_en content_fr content_es content_uk
            attribution_en attribution_fr attribution_es attribution_uk
            alt_text_en alt_text_fr alt_text_es alt_text_uk
            caption_en caption_fr caption_es caption_uk
            diagram_source_en diagram_source_fr diagram_source_es diagram_source_uk
          ]
        end

        def self.updatable_fields(context)
          creatable_fields(context) - %i[block_type]
        end

        # Map :block_type from request attributes to model STI type column.
        # For new records, re-instantiate @model as the correct STI subclass so
        # that subtype-specific Storext and Mobility accessors are available.
        def _assign_attributes(resource_params)
          if (block_type = resource_params.delete(:block_type))
            class_name = self.class.resolve_block_class(block_type)
            klass = class_name&.safe_constantize
            unless klass && klass < ::BetterTogether::Content::Block
              raise JSONAPI::Exceptions::InvalidFieldValue.new(:block_type, block_type)
            end

            @model = klass.new if @model.new_record? && !@model.is_a?(klass)
            @model.type = klass.name
          end
          super
        end

        # Resolve a short or full block type name to its full Rails STI class name.
        # Accepts: "Markdown", "Content::Markdown", "BetterTogether::Content::Markdown"
        def self.resolve_block_class(value)
          return value if value.nil?

          name = value.to_s
          return name if name.start_with?('BetterTogether::')

          name = "Content::#{name}" unless name.start_with?('Content::')
          "BetterTogether::#{name}"
        end
      end
      # rubocop:enable Metrics/ClassLength

      # JSONAPI-Resources STI aliases — must live in the same file as BlockResource
      # so Zeitwerk loads them together.  Any new Content::Block STI subtype must
      # be added here.
      AccordionBlockResource      = BlockResource
      AlertBlockResource          = BlockResource
      CallToActionBlockResource   = BlockResource
      ChecklistBlockResource      = BlockResource
      CommunitiesBlockResource    = BlockResource
      CssResource                 = BlockResource
      EventsBlockResource         = BlockResource
      HeroResource                = BlockResource
      HtmlResource                = BlockResource
      ImageResource               = BlockResource
      MarkdownResource            = BlockResource
      MermaidDiagramResource      = BlockResource
      NavigationAreaBlockResource = BlockResource
      PeopleBlockResource         = BlockResource
      PostsBlockResource          = BlockResource
      QuoteBlockResource          = BlockResource
      RichTextResource            = BlockResource
      StatisticsBlockResource     = BlockResource
      TemplateResource            = BlockResource
      VideoBlockResource          = BlockResource
    end
  end
end
