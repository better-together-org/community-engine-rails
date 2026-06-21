# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/events/_host.html.erb' do
  before do
    configure_host_platform
  end

  def stub_profile_image_tag(host, image_src)
    view.define_singleton_method(:profile_image_tag) do |_entity, **_options|
      %(<img src="#{image_src}" alt="#{host.name}">).html_safe
    end
  end

  def stub_host_view_dependencies(host, image_src:)
    stub_profile_image_tag(host, image_src)
    allow(view).to receive(:policy).with(host).and_return(double(show?: true))
    allow(view).to receive(:polymorphic_path).with(host).and_return("/hosts/#{host.id}")
  end

  it 'renders a person host avatar and link' do
    host = create(:better_together_person, name: 'Person Host')
    stub_host_view_dependencies(host, image_src: '/rails/active_storage/proxy/person-host')

    render partial: 'better_together/events/host', locals: { host:, size: 32, show_name: true }

    expect(rendered).to include('/rails/active_storage/proxy/person-host')
    expect(rendered).to include('Person Host')
    expect(rendered).to include(%(href="/hosts/#{host.id}"))
  end

  it 'renders a community host avatar and link' do
    host = create(:better_together_community, name: 'Community Host')
    stub_host_view_dependencies(host, image_src: '/rails/active_storage/proxy/community-host')

    render partial: 'better_together/events/host', locals: { host:, size: 32, show_name: true }

    expect(rendered).to include('/rails/active_storage/proxy/community-host')
    expect(rendered).to include('Community Host')
  end

  it 'renders a platform host avatar and link' do
    host = create(:better_together_platform, name: 'Platform Host')
    stub_host_view_dependencies(host, image_src: '/rails/active_storage/proxy/platform-host')

    render partial: 'better_together/events/host', locals: { host:, size: 32, show_name: true }

    expect(rendered).to include('/rails/active_storage/proxy/platform-host')
    expect(rendered).to include('Platform Host')
  end
end
