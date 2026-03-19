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
      class BlockResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Content::Block'

        # ── Core identity ────────────────────────────────────────────────────────
        attributes :type, :identifier, :privacy, :visible, :protected

        # Computed label describing the block type (demodulized underscored)
        attribute :block_name do
          @model.block_name
        end

        # ── Storext content_data attrs (all STI subtypes, flat) ──────────────────
        # These delegate via method_missing on the model — Storext sets them.
        attributes :heading, :accordion_items_json, :open_first,
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
        filter :type
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
            type identifier privacy visible
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
          creatable_fields(context) - %i[type]
        end
      end
    end
  end
end
