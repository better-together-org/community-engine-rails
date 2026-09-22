# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/feedback_surface' do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:page_record) do
    create(:better_together_page,
           title: 'Shared Kitchen Guide',
           slug: "feedback-surface-#{SecureRandom.hex(4)}",
           identifier: "feedback-surface-#{SecureRandom.hex(4)}",
           protected: false,
           published_at: 1.day.ago,
           privacy: 'public')
  end

  before do
    view.singleton_class.include BetterTogether::FeedbackSurfaceHelper
    allow(view).to receive_messages(current_user: user, current_person: user.person)
  end

  it 'renders a panel surface with a visible report action and policy note' do
    render partial: 'shared/feedback_surface', locals: { record: page_record, presentation: :panel, surface_scope: :page }

    expect(rendered).to include('Page feedback')
    expect(rendered).to include('Report safety issue')
    expect(rendered).to include('Sent privately to the platform safety team')
    expect(rendered).to include("reportable_id=#{page_record.id}")
  end

  it 'renders a compact surface for section-scoped feedback' do
    render partial: 'shared/feedback_surface', locals: { record: page_record, presentation: :compact, surface_scope: :section }

    expect(rendered).to include('Section feedback')
    expect(rendered).to include('Report safety issue')
    expect(rendered).to include('btn btn-outline-danger btn-sm')
  end

  it 'renders nothing when the feedback surface is not available' do
    allow(view).to receive_messages(current_user: nil, current_person: nil)

    render partial: 'shared/feedback_surface', locals: { record: page_record, presentation: :panel, surface_scope: :page }

    expect(rendered.to_s.strip).to eq('')
  end
end
