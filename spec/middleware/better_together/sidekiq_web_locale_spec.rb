# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SidekiqWebLocale do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(env) { [200, {}, [env['rack.session'][:locale].to_s]] } }

  def call(query, session = {})
    env = Rack::MockRequest.env_for("/sidekiq/?#{query}")
    env['rack.session'] = session
    middleware.call(env)
    session
  end

  describe '.match' do
    it 'keeps a locale Sidekiq ships', :aggregate_failures do
      %w[en es fr uk].each { |locale| expect(described_class.match(locale)).to eq(locale) }
    end

    it 'matches regional variants by case and separator' do
      expect(described_class.match('pt_br')).to eq('pt-BR')
    end

    it 'falls back to the base language for a region Sidekiq lacks' do
      expect(described_class.match('fr-CA')).to eq('fr')
    end

    it 'falls back to English for a language Sidekiq lacks' do
      expect(described_class.match('iu')).to eq('en')
    end

    it 'ignores blank or malformed values', :aggregate_failures do
      expect(described_class.match('')).to be_nil
      expect(described_class.match('../../etc/passwd')).to be_nil
    end
  end

  describe '#call' do
    it 'stores the mapped locale where Sidekiq reads it (session[:locale])' do
      expect(call('locale=uk')[:locale]).to eq('uk')
    end

    it 'leaves the session alone without a locale param' do
      expect(call('', { locale: 'es' })[:locale]).to eq('es')
    end

    it 'ignores a locale given as an array' do
      expect(call('locale[]=fr', { locale: 'es' })[:locale]).to eq('es')
    end

    it 'passes the request on to Sidekiq' do
      env = Rack::MockRequest.env_for('/sidekiq/?locale=fr')
      env['rack.session'] = {}

      expect(middleware.call(env)).to eq([200, {}, ['fr']])
    end
  end
end
