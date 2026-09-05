# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# rubocop:disable RSpec/DescribeClass, RSpec/SpecFilePathFormat
RSpec.describe 'better_together:generate:agreements', type: :task do
  around do |example|
    previous_clear = ENV.delete('CLEAR')
    example.run
    ENV['CLEAR'] = previous_clear
  end

  before do
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/generate.rake')
    Rake::Task.define_task(:environment)
    Current.platform = BetterTogether::Platform.find_by(host: true)
    task.reenable
  end

  after do
    Current.platform = nil
  end

  let(:task) { Rake::Task['better_together:generate:agreements'] }

  it 'preserves existing agreement participation by default while seeding missing agreements' do
    agreement = BetterTogether::Agreement.find_by!(identifier: 'privacy_policy')
    participant = create(
      :better_together_agreement_participant,
      agreement:,
      accepted_at: Time.current
    )

    task.invoke

    expect(BetterTogether::AgreementParticipant.exists?(participant.id)).to be(true)
    expect(
      BetterTogether::Agreement.find_by(identifier: 'content_publishing_agreement')&.page&.slug
    ).to eq('content-contributor-agreement')
  end

  it 'supports explicit destructive rebuilds when CLEAR=1 is set' do
    agreement = BetterTogether::Agreement.find_by!(identifier: 'privacy_policy')
    create(
      :better_together_agreement_participant,
      agreement:,
      accepted_at: Time.current
    )

    ENV['CLEAR'] = '1'

    task.invoke

    expect(BetterTogether::AgreementParticipant.count).to eq(0)
    expect(BetterTogether::Agreement.find_by!(identifier: 'content_publishing_agreement')).to be_present
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/SpecFilePathFormat
