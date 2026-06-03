# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/fields/_hero.html.erb' do
  helper BetterTogether::Content::BlocksHelper
  helper BetterTogether::TranslatableFieldsHelper

  let(:scope) { 'page[page_blocks_attributes][0][block_attributes]' }
  let(:temp_id) { 'hero-partial-spec' }
  let(:block) { build(:better_together_content_hero) }

  before do
    view.define_singleton_method(:current_person) { nil }
    view.define_singleton_method(:policy_scope) do |_scope|
      BetterTogether::Community.none
    end
    view.main_app.define_singleton_method(:rails_direct_uploads_url) do
      '/rails/active_storage/direct_uploads'
    end
    view.main_app.define_singleton_method(:rails_service_blob_url) do |*_args, **_options|
      '/rails/active_storage/blobs/test'
    end
    allow(BetterTogether::Upload).to receive(:with_creator).and_return([])
    allow(BetterTogether::Engine.routes.url_helpers).to receive(:ai_translate_path).and_return('/ai/translate')
  end

  it 'renders hero editor labels through locale keys instead of hard-coded English text' do
    I18n.with_locale(:fr) do
      render partial: 'better_together/content/blocks/fields/hero',
             locals: { block:, scope:, temp_id: }

      expect(rendered).to include('Bouton d’appel à l’action')
      expect(rendered).to include('Arrière-plan')
      expect(rendered).to include('Couleur de superposition')
      expect(rendered).to include('Couleur du titre')
      expect(rendered).to include('Couleur du paragraphe')
      expect(rendered).to include('Veuillez fournir une URL valide commençant par http:// ou https://.')
      expect(rendered).not_to include('CTA Button')
      expect(rendered).not_to include('Background')
      expect(rendered).not_to include('Overlay Color')
    end
  end
end
