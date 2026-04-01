# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'devise/shared/_omniauth_buttons' do
  before do
    allow(view).to receive_messages(
      devise_mapping: double(omniauthable?: true),
      resource_class: BetterTogether::User,
      resource_name: :user
    )
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
end
