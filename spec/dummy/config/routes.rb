# frozen_string_literal: true

require 'rswag'

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/bt/api/docs'
  mount Rswag::Api::Engine => '/bt/api/docs'
  mount BetterTogether::Engine => '/'
  root to: redirect('/bt')
end
