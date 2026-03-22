# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:todo RSpec/SpecFilePathFormat
  RSpec.describe ActiveStorageSecurity do
    # rubocop:enable RSpec/SpecFilePathFormat

    # Build a minimal anonymous controller that includes the concern so we can
    # unit-test the private helpers without standing up full AS routing.
    let(:controller_class) do
      Class.new(ActionController::Base) do
        include BetterTogether::ActiveStorageSecurity

        # Stubs for Devise helpers injected at runtime
        attr_writer :current_user, :user_signed_in

        def user_signed_in?
          @user_signed_in
        end
      end
    end

    let(:controller) { controller_class.new }

    describe '#publicly_accessible?' do
      context 'when the record is nil' do
        it 'returns false' do
          expect(controller.send(:publicly_accessible?, nil)).to be false
        end
      end

      context 'when the record does not respond to privacy_public?' do
        it 'returns false' do
          expect(controller.send(:publicly_accessible?, Object.new)).to be false
        end
      end

      context 'when the record is privacy_public?' do
        let(:record) { instance_double(BetterTogether::Upload, privacy_public?: true) }

        it 'returns true' do
          expect(controller.send(:publicly_accessible?, record)).to be true
        end
      end

      context 'when the record is not privacy_public?' do
        let(:record) { instance_double(BetterTogether::Upload, privacy_public?: false) }

        it 'returns false' do
          expect(controller.send(:publicly_accessible?, record)).to be false
        end
      end
    end

    describe '#enforce_download_policy!' do
      let(:user) { build_stubbed(:better_together_person) }
      let(:record) { instance_double(BetterTogether::Upload) }

      before { controller.current_user = user }

      context 'when the policy has no download? method' do
        let(:policy) { instance_double(BetterTogether::ApplicationPolicy) }

        before do
          allow(Pundit).to receive(:policy).with(user, record).and_return(policy)
          allow(policy).to receive(:respond_to?).with(:download?).and_return(false)
        end

        it 'does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:enforce_download_policy!, record)
        end
      end

      context 'when download? returns true' do
        let(:policy) { instance_double(BetterTogether::UploadPolicy, download?: true) }

        before do
          allow(Pundit).to receive(:policy).with(user, record).and_return(policy)
          allow(policy).to receive(:respond_to?).with(:download?).and_return(true)
        end

        it 'does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:enforce_download_policy!, record)
        end
      end

      context 'when download? returns false' do
        let(:policy) { instance_double(BetterTogether::UploadPolicy, download?: false) }

        before do
          allow(Pundit).to receive(:policy).with(user, record).and_return(policy)
          allow(policy).to receive(:respond_to?).with(:download?).and_return(true)
        end

        it 'renders 403' do
          expect(controller).to receive(:head).with(:forbidden)
          controller.send(:enforce_download_policy!, record)
        end
      end

      context 'when Pundit raises NotAuthorizedError' do
        before do
          allow(Pundit).to receive(:policy).with(user, record).and_raise(Pundit::NotAuthorizedError)
        end

        it 'renders 403' do
          expect(controller).to receive(:head).with(:forbidden)
          controller.send(:enforce_download_policy!, record)
        end
      end
    end

    describe 'initializer wires up AS proxy and redirect controllers' do
      it 'includes the concern in ActiveStorage::Blobs::ProxyController' do
        expect(ActiveStorage::Blobs::ProxyController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Blobs::RedirectController' do
        expect(ActiveStorage::Blobs::RedirectController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Representations::ProxyController' do
        expect(ActiveStorage::Representations::ProxyController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Representations::RedirectController' do
        expect(ActiveStorage::Representations::RedirectController.ancestors).to include(described_class)
      end
    end
  end
end
