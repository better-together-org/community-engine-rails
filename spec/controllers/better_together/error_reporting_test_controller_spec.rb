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

  around do |example|
    original_registry = BetterTogether.adapter_registry
    BetterTogether.adapter_registry = BetterTogether::AdapterRegistry.new
    example.run
    BetterTogether.adapter_registry = original_registry
  end

  it 'logs rescued production exceptions and reports them through the configured adapter registry' do
    adapter = instance_double(Proc)
    allow(adapter).to receive(:call)
    BetterTogether.register_error_reporter(:test, adapter)

    get :index, params: { locale: 'en' }

    expect(response).to have_http_status(:internal_server_error)
    expect(flash[:error]).to eq('boom')
    expect(logger).to have_received(:error).with(include('[PRODUCTION][Exception] StandardError: boom'))
    expect(logger).to have_received(:error).with(include('method=GET'))
    expect(logger).to have_received(:error).with(include('path=/index?locale=en'))
    expect(logger).to have_received(:error).at_least(:twice)
    expect(adapter).to have_received(:call).with(
      instance_of(StandardError),
      context: hash_including(
        request_id: nil,
        request_method: 'GET',
        path: '/index?locale=en',
        controller: 'error_reporting_test',
        action: 'index',
        user_id: 'anonymous'
      )
    )
    expect(log_output.string).to include('[PRODUCTION][Exception] StandardError: boom')
  end

  it 'logs adapter failures without masking the original 500 response' do
    BetterTogether.register_error_reporter(:failing, lambda do |_exception, context:|
      raise StandardError, "adapter down for #{context[:request_id]}"
    end)

    get :index, params: { locale: 'en' }

    expect(response).to have_http_status(:internal_server_error)
    expect(logger).to have_received(:error).with(include('[PRODUCTION][ErrorReportingFailure] StandardError: adapter down for '))
    expect(log_output.string).to include('[PRODUCTION][ErrorReportingFailure] StandardError: adapter down for ')
  end
end
