# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe AgreementBuilder, type: :builder do
    before do
      Current.platform = BetterTogether::Platform.find_by(host: true)
    end

    after do
      Current.platform = nil
    end

    describe '.seed_data' do
      it 'creates and links the content publishing agreement page when missing', :aggregate_failures do
        remove_page_by(slug: 'content-contributor-agreement')

        agreement = BetterTogether::Agreement.find_or_initialize_by(identifier: 'content_publishing_agreement')
        agreement.page = nil
        agreement.save! if agreement.persisted?

        described_class.seed_data

        agreement.reload
        page = agreement.page
        template_block = page.template_blocks.detect do |block|
          block.template_path == 'better_together/static_pages/content_contributor_agreement'
        end

        expect(page).to be_present
        expect(page.slug).to eq('content-contributor-agreement')
        expect(template_block).to be_present
      end

      it 'links seeded agreements to their deterministic page identifiers' do
        described_class.seed_data

        expect(BetterTogether::Agreement.find_by!(identifier: 'privacy_policy').page&.slug).to eq('privacy-policy')
        expect(BetterTogether::Agreement.find_by!(identifier: 'terms_of_service').page&.slug).to eq('terms-of-service')
        expect(BetterTogether::Agreement.find_by!(identifier: 'code_of_conduct').page&.slug).to eq('code-of-conduct')
        expect(BetterTogether::Agreement.find_by!(identifier: 'content_publishing_agreement').page&.slug).to eq('content-contributor-agreement')
      end
    end

    private

    def remove_page_by(slug:)
      page = BetterTogether::Page.i18n.find_by(slug:)
      return unless page

      BetterTogether::Agreement.where(page: page).update_all(page_id: nil)
      page.navigation_items.update_all(linkable_id: nil, linkable_type: nil)
      page.page_blocks.delete_all
      page.delete
    end
  end
end
