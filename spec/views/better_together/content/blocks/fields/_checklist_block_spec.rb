# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/fields/_checklist_block.html.erb' do
  helper BetterTogether::Content::BlocksHelper

  let(:scope) { 'block' }
  let(:temp_id) { 'checklist-block-spec' }
  let!(:community) { create(:better_together_community, name: 'Documentation Community') }
  let!(:checklist) { create(:better_together_checklist, title: 'Documentation Checklist') }

  before do
    configure_host_platform
    scoped_community = community
    scoped_checklist = checklist
    view.define_singleton_method(:policy_scope) do |scope_class|
      case scope_class.name
      when 'BetterTogether::Community'
        BetterTogether::Community.where(id: scoped_community.id)
      when 'BetterTogether::Checklist'
        BetterTogether::Checklist.where(id: scoped_checklist.id)
      else
        scope_class.none
      end
    end
  end

  it 'renders the shared resource fields and checklist selector without ordering errors' do
    block = BetterTogether::Content::ChecklistBlock.new(display_style: 'grid', item_limit: 6)
    block.checklist_id = checklist.id

    render partial: 'better_together/content/blocks/fields/checklist_block',
           locals: { block:, scope:, temp_id: }

    page = Capybara.string(rendered)

    expect(page).to have_css('[name="block[display_style]"]', visible: :all)
    expect(page).to have_css('[name="block[item_limit]"]', visible: :all)
    expect(page).to have_css('[name="block[community_scope_id]"]', visible: :all)
    expect(page).to have_css('[name="block[checklist_id]"]', visible: :all)
    expect(page).to have_text('Documentation Checklist')
    expect(page).to have_text('Documentation Community')
  end
end
