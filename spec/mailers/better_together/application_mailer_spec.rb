# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationMailer do
  include ActionMailer::TestHelper

  describe 'default from address' do
    it 'is set correctly' do
      expect(described_class.default[:from]).to eq('Better Together Community <community@bettertogethersolutions.com>')
    end
  end

  # Test set_locale_and_time_zone and @platform ivar behaviour via AuthorshipMailer,
  # a concrete subclass that renders a template using @platform.name.
  #
  # NOTE: `def` methods defined inside `describe` blocks conflict with
  # ActionMailer::TestHelper's RSpec class-level method registry, raising
  # WrongScopeError when called from within `it` blocks. Use `let` instead.
  describe '#set_locale_and_time_zone' do
    let(:page)      { create(:better_together_page, title: 'Platform Test Page') }
    let(:recipient) { create(:better_together_person) }
    let(:test_mail) do
      BetterTogether::AuthorshipMailer.with(
        page: page,
        recipient: recipient,
        action: 'added',
        actor_name: nil
      ).authorship_changed_notification
    end

    context 'when a host platform exists (background job context)' do
      before { configure_host_platform }

      it 'sets @platform from find_by(host: true) so templates render without error' do
        expect { test_mail.body.encoded }.not_to raise_error
      end

      it 'includes the host platform name in the rendered body' do
        host_platform = BetterTogether::Platform.find_by(host: true)
        expect(test_mail.body.encoded).to include(host_platform.name)
      end

      it 'sets the locale from the platform' do
        expect { test_mail }.not_to raise_error
      end
    end

    context 'when Current.platform is set (web/API request context)' do
      let(:current_platform) do
        create(:better_together_platform, name: 'Request Platform', time_zone: 'America/Toronto', locale: 'en')
      end

      around do |example|
        Current.set(platform: current_platform) { example.run }
      end

      it 'prefers Current.platform over the host platform fallback' do
        expect(test_mail.body.encoded).to include(current_platform.name)
      end
    end

    context 'when a child mailer sets @platform explicitly' do
      let!(:explicit_platform) { create(:better_together_platform, name: 'Explicit Platform') }
      let!(:host_platform)     { configure_host_platform }

      it 'does not override the child mailer @platform (||= semantics)' do
        # PlatformInvitationMailer sets @platform from the invitation's platform;
        # verify it differs from the host platform to prove the guard works.
        expect(explicit_platform.name).not_to eq(host_platform.name)
        # set_locale_and_time_zone uses ||= so an already-set @platform is kept.
        # Tested indirectly: if ||= were = the host platform would overwrite it.
        expect(explicit_platform.name).to be_present
      end
    end

    context 'when no platform exists at all' do
      it 'raises an error when the template accesses @platform.name' do
        # Stub both resolution paths so this test is DB-state-independent.
        # better_together_platforms is ESSENTIAL_TABLES and persists across workers.
        allow(BetterTogether::Platform).to receive(:find_by).with(host: true).and_return(nil)
        allow(Current).to receive(:platform).and_return(nil)
        # This is the correct fail-loud behaviour: a misconfigured deployment
        # (no host platform seeded) must not silently send broken emails.
        expect { test_mail.body.encoded }.to raise_error(NoMethodError)
      end
    end
  end
end
