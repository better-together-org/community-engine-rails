# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:todo RSpec/SpecFilePathFormat
  RSpec.describe DirectUploadSecurity, :no_auth, :skip_host_setup do
    # rubocop:enable RSpec/SpecFilePathFormat

    # Build a minimal anonymous controller that includes the concern so we can
    # unit-test the private helper without standing up full AS routing.
    let(:controller_class) do
      Class.new(ActionController::Base) do
        include BetterTogether::DirectUploadSecurity

        attr_writer :user_signed_in

        def user_signed_in?
          @user_signed_in
        end
      end
    end

    let(:controller) { controller_class.new }

    before do
      controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.create)
    end

    describe '#require_authentication_for_direct_upload' do
      context 'when signed in' do
        before { controller.user_signed_in = true }

        it 'does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:require_authentication_for_direct_upload)
        end
      end

      context 'when not signed in' do
        before { controller.user_signed_in = false }

        it 'renders 401' do
          expect(controller).to receive(:head).with(:unauthorized)
          controller.send(:require_authentication_for_direct_upload)
        end
      end
    end

    describe 'initializer wires up ActiveStorage::DirectUploadsController' do
      it 'includes the concern' do
        expect(ActiveStorage::DirectUploadsController.ancestors).to include(described_class)
      end
    end
  end
end
