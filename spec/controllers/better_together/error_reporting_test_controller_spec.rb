# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

module BetterTogether
  class ErrorReportingTestController < ApplicationController
    skip_before_action :check_platform_setup
    skip_before_action :check_platform_privacy
    skip_before_action :set_platform_invitation
    skip_before_action :handle_debug_mode
    skip_before_action :set_debug_headers

    def index
      raise StandardError, 'boom'
    end
  end
end

RSpec.describe BetterTogether::ErrorReportingTestController do
  let(:log_output) { StringIO.new }
  let(:logger) do
    Logger.new(log_output).tap do |value|
      allow(value).to receive(:error).and_call_original
    end
  end
  let(:production_env) { ActiveSupport::StringInquirer.new('production') }

  before do
    routes.draw { get 'index' => 'better_together/error_reporting_test#index' }

    allow(Rails).to receive_messages(env: production_env, logger:)
    allow(controller.request).to receive_messages(request_id: 'req-123', request_method: 'GET')
    allow(controller).to receive(:current_user).and_return(nil)
  end

  it 'logs rescued production exceptions and reports them to sentry' do
    allow(Sentry).to receive(:capture_exception)

    get :index, params: { locale: 'en' }

    expect(response).to have_http_status(:internal_server_error)
    expect(flash[:error]).to eq('boom')
    expect(logger).to have_received(:error).with(include('[PRODUCTION][Exception] StandardError: boom'))
    expect(logger).to have_received(:error).with(include('method=GET'))
    expect(logger).to have_received(:error).with(include('path=/index?locale=en'))
    expect(logger).to have_received(:error).at_least(:twice)
    expect(Sentry).to have_received(:capture_exception).with(instance_of(StandardError))
    expect(log_output.string).to include('[PRODUCTION][Exception] StandardError: boom')
  end

  it 'logs sentry capture failures without masking the original 500 response' do
    allow(Sentry).to receive(:capture_exception).and_raise(StandardError, 'sentry down')

    get :index, params: { locale: 'en' }

    expect(response).to have_http_status(:internal_server_error)
    expect(logger).to have_received(:error).with(include('[PRODUCTION][SentryCaptureFailure] StandardError: sentry down'))
    expect(log_output.string).to include('[PRODUCTION][SentryCaptureFailure] StandardError: sentry down')
  end
end
