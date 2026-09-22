# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:todo RSpec/SpecFilePathFormat
  RSpec.describe DirectUploadAuthorization, :no_auth, :skip_host_setup do
    # rubocop:enable RSpec/SpecFilePathFormat

    # Build a minimal anonymous controller that includes the concern so we can
    # unit-test the private helper without standing up full AS routing.
    let(:controller_class) do
      Class.new(ActionController::Base) do
        include BetterTogether::DirectUploadAuthorization
      end
    end

    let(:controller) { controller_class.new }
    let(:verifier) { Rails.application.message_verifier(:direct_upload) }

    before do
      controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.create)
    end

    describe '#verify_direct_upload_token' do
      context 'when the token header is missing' do
        before do
          controller.instance_variable_set(:@_request,
                                           ActionDispatch::TestRequest.create('HTTP_X_DIRECT_UPLOAD_TOKEN' => nil))
        end

        it 'renders 401' do
          expect(controller).to receive(:head).with(:unauthorized)
          controller.send(:verify_direct_upload_token)
        end
      end

      context 'when the token is valid and unexpired' do
        let(:token) { verifier.generate({ path: '/en/users/sign_up', iat: Time.current.to_i }, expires_in: 30.minutes) }

        before do
          controller.instance_variable_set(:@_request,
                                           ActionDispatch::TestRequest.create('HTTP_X_DIRECT_UPLOAD_TOKEN' => token))
        end

        it 'does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:verify_direct_upload_token)
        end
      end

      context 'when the token is expired' do
        let(:token) do
          travel_to(35.minutes.ago) do
            verifier.generate({ path: '/en/users/sign_up', iat: Time.current.to_i }, expires_in: 30.minutes)
          end
        end

        before do
          controller.instance_variable_set(:@_request,
                                           ActionDispatch::TestRequest.create('HTTP_X_DIRECT_UPLOAD_TOKEN' => token))
        end

        it 'renders 401' do
          expect(controller).to receive(:head).with(:unauthorized)
          controller.send(:verify_direct_upload_token)
        end
      end

      context 'when the token has an invalid signature' do
        before do
          controller.instance_variable_set(:@_request,
                                           ActionDispatch::TestRequest.create('HTTP_X_DIRECT_UPLOAD_TOKEN' => 'garbage-not-a-real-token'))
        end

        it 'renders 401' do
          expect(controller).to receive(:head).with(:unauthorized)
          controller.send(:verify_direct_upload_token)
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
