# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a template from a file
    class Template < Block
      class_attribute :available_templates, default: %w[
        better_together/content/blocks/template/default
        better_together/content/blocks/template/host_community_contact_details
        better_together/static_pages/privacy
        better_together/static_pages/terms_of_service
        better_together/static_pages/code_of_conduct
        better_together/static_pages/accessibility
        better_together/static_pages/cookie_consent
        better_together/static_pages/code_contributor_agreement
        better_together/static_pages/content_contributor_agreement
        better_together/static_pages/faq
        better_together/static_pages/better_together
        better_together/static_pages/community_engine
        better_together/static_pages/subprocessors
      ]

      store_attributes :content_data do
        template_path String
      end

      validates :template_path, presence: true, inclusion: { in: ->(template) { template.class.available_templates } }
    end
  end
end
