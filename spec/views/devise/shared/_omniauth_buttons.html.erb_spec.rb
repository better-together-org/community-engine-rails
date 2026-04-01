# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'devise/shared/_omniauth_buttons' do
  before do
    view.extend BetterTogether::OauthButtonsHelper

    mapping = double(omniauthable?: true, to: BetterTogether::User, name: :user)
    resource_klass = BetterTogether::User
    resource_identifier = :user

    view.define_singleton_method(:devise_mapping) { mapping }
    view.define_singleton_method(:resource_class) { resource_klass }
    view.define_singleton_method(:resource_name) { resource_identifier }
  end

  def render_buttons
    render partial: 'devise/shared/omniauth_buttons'
  end

  it 'does not render the GitHub button when credentials are missing' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_ID', nil).and_return(nil)
    allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_SECRET', nil).and_return('client_secret_456')

    render_buttons

    expect(rendered).not_to include('Sign in with GitHub')
    expect(rendered).not_to include('/users/auth/github')
  end

  it 'renders the GitHub button when credentials are present' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_ID', nil).and_return('client_id_123')
    allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_SECRET', nil).and_return('client_secret_456')

    render_buttons

    expect(rendered).to include('Sign in with GitHub')
  end

  it 'does not error when resource_class is nil and credentials are missing' do
    view.define_singleton_method(:resource_class) { nil }
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_ID', nil).and_return(nil)
    allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_SECRET', nil).and_return(nil)

    expect { render_buttons }.not_to raise_error
    expect(rendered).not_to include('Sign in with GitHub')
  end
end
