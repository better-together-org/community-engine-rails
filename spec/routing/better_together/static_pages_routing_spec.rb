# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::StaticPagesController, type: :routing do
  describe 'routing' do
    it 'routes to #community_engine' do
      expect(get: ::BetterTogether::Engine.routes.url_helpers.community_engine_path).to route_to(
        locale: I18n.default_locale.to_s,
        controller: 'better_together/pages',
        action: 'show',
        path: 'bt'
      )
    end
  end
end
