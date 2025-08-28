require 'rails_helper'

RSpec.describe 'Event show attendees tab', type: :view do
  let(:manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let(:event) do
    BetterTogether::Event.create!(
      name: 'Neighborhood Clean-up',
      starts_at: 1.day.from_now,
      identifier: SecureRandom.uuid,
      privacy: 'public',
      creator: manager_user.person
    )
  end

  it 'shows attendees tab to organizers' do
    invitation = BetterTogether::EventInvitation.new(invitable: event, inviter: manager_user.person)
    allow(view).to receive(:policy).and_call_original
    allow(view).to receive(:current_person).and_return(manager_user.person)
    allow(view).to receive(:policy).with(invitation).and_return(double(create?: true))

    assign(:event, event)
    assign(:resource, event)

    render template: 'better_together/events/show'

    expect(rendered).to include('Attendees')
  end
end
