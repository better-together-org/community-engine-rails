# frozen_string_literal: true

module BetterTogether
  module Content
    # Helpers for Content Blocks
    module BlocksHelper
      TEMPLATE_TRANSLATION_KEYS = {
        'better_together/content/blocks/template/default' => 'better_together.content.blocks.template.default',
        'better_together/content/blocks/template/host_community_contact_details' =>
          'better_together.content.blocks.template.host_community_contact_details',
        'better_together/static_pages/privacy' => 'better_together.static_pages.privacy',
        'better_together/static_pages/terms_of_service' => 'better_together.static_pages.terms_of_service',
        'better_together/static_pages/code_of_conduct' => 'better_together.static_pages.code_of_conduct',
        'better_together/static_pages/accessibility' => 'better_together.static_pages.accessibility',
        'better_together/static_pages/cookie_consent' => 'better_together.static_pages.cookie_consent',
        'better_together/static_pages/code_contributor_agreement' =>
          'better_together.static_pages.code_contributor_agreement',
        'better_together/static_pages/content_contributor_agreement' =>
          'better_together.static_pages.content_contributor_agreement',
        'better_together/static_pages/faq' => 'better_together.static_pages.faq',
        'better_together/static_pages/better_together' => 'better_together.static_pages.better_together',
        'better_together/static_pages/community_engine' => 'better_together.static_pages.community_engine',
        'better_together/static_pages/subprocessors' => 'better_together.static_pages.subprocessors'
      }.freeze

      def acceptable_image_file_types = BetterTogether::Attachments::Images::VALID_IMAGE_CONTENT_TYPES

      def temp_id_for(model, temp_id: SecureRandom.uuid) = model.persisted? ? model.id : temp_id

      # Sanitize HTML content for safe rendering in custom blocks
      def sanitize_block_html(html)
        allowed_tags = %w[p br strong em b i ul ol li a span h1 h2 h3 h4 h5 h6 img figure figcaption blockquote pre
                          code iframe div]
        allowed_attrs = %w[href src alt style title class target rel]
        sanitize(html.to_s, tags: allowed_tags, attributes: allowed_attrs)
      end

      # Very basic CSS sanitizer: strips dangerous patterns
      def sanitize_block_css(css)
        return '' if css.blank?

        sanitized = css.to_s.dup
        # Remove expression() and javascript: and url(javascript:...) patterns
        sanitized.gsub!(/expression\s*\(/i, '')
        sanitized.gsub!(/url\s*\(\s*javascript:[^)]*\)/i, 'url("")')
        sanitized
      end

      # Returns data attributes for mermaid controller if markdown contains mermaid diagrams
      def mermaid_controller_attributes(markdown)
        return {} unless markdown.contains_mermaid?

        { data: { controller: 'better-together--mermaid' } }
      end

      def template_options_for(block)
        block.class.available_templates.map do |path|
          key = TEMPLATE_TRANSLATION_KEYS.fetch(path, path.tr('/', '.'))
          [I18n.t(key, default: path.tr('/', ' ').tr('_', ' ').titleize), path]
        end
      end

      def iframe_embed_state(url)
        origin = BetterTogether::ContentSecurityPolicySources.origin_for_url(url)
        return { status: :invalid, origin: nil, allowed_sources: resolved_frame_sources } if origin.nil?

        {
          status: iframe_origin_allowed?(origin) ? :allowed : :blocked,
          origin: origin,
          allowed_sources: resolved_frame_sources
        }
      end

      def resolved_frame_sources
        @resolved_frame_sources ||= BetterTogether::ContentSecurityPolicySources.frame_sources.flat_map do |source|
          source.respond_to?(:call) ? Array(instance_exec(&source)) : [source]
        end.uniq
      end

      def iframe_origin_allowed?(origin)
        current_origin = BetterTogether::ContentSecurityPolicySources.origin_for_url(request&.base_url)
        resolved_frame_sources.any? do |source|
          source == origin || (source == :self && current_origin.present? && current_origin == origin)
        end
      end

      def iframe_embed_cache_key(block, url)
        [block.cache_key_with_version, request&.base_url,
         BetterTogether::ContentSecurityPolicySources.origin_for_url(url), resolved_frame_sources]
      end

      # Returns a privacy-scoped, optionally community-scoped, limited collection
      # for a resource collection block.
      def resource_block_collection(block, resource_class, extra_scope: nil)
        ids = block.parsed_resource_ids

        scope = if ids.any?
                  resource_class.where(id: ids)
                else
                  policy_scope(resource_class)
                end

        scope = apply_community_scope(scope, resource_class, block.scoped_community) if block.scoped_community.present?

        scope = extra_scope.call(scope) if extra_scope.present?
        scope.limit(block.item_limit)
      end

      private

      # Applies a community join/filter appropriate for the given resource_class.
      def apply_community_scope(scope, resource_class, community) # rubocop:disable Metrics/MethodLength
        case resource_class.name
        when 'BetterTogether::Event'
          scope.joins(:event_hosts).where(better_together_event_hosts: { host_id: community.id,
                                                                         host_type: community.class.name })
        when 'BetterTogether::Post'
          scope.joins(:authorships)
               .where(better_together_authorships: { author_id: community.id,
                                                     author_type: community.class.name })
        when 'BetterTogether::Person'
          scope.joins(:person_community_memberships)
               .where(better_together_person_community_memberships: { community_id: community.id })
        when 'BetterTogether::Community'
          scope.where(id: community.id)
        else
          scope
        end
      end
    end
  end
end
