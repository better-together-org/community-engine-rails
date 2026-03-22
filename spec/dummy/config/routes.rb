# frozen_string_literal: true

Rails.application.routes.draw do
  mount BetterTogether::Engine => '/'
  root to: redirect('/')
end
