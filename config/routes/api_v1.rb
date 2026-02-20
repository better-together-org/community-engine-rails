# frozen_string_literal: true

# API v1 resource routes

namespace :v1 do # rubocop:disable Metrics/BlockLength
  # People
  get 'people/me', to: 'people#me'
  jsonapi_resources :people
  # NOTE: Relationship routes omitted until all related resources exist

  # Communities
  jsonapi_resources :communities
  # NOTE: Relationship routes omitted until all related resources exist

  # Roles (read-only)
  jsonapi_resources :roles, only: %i[index show]

  # Events
  jsonapi_resources :events

  # Posts
  jsonapi_resources :posts

  # Conversations
  jsonapi_resources :conversations, only: %i[index show create update]

  # Messages (create-only for sending, index/show for reading)
  jsonapi_resources :messages, only: %i[index show create]

  # Notifications (read + mark as read)
  jsonapi_resources :notifications, only: %i[index show update]
  post 'notifications/mark_all_read', to: 'notifications#mark_all_read'

  # Person Community Memberships
  jsonapi_resources :person_community_memberships, only: %i[index show create update]

  # Person Blocks
  jsonapi_resources :person_blocks, only: %i[index show create destroy]

  # Invitations
  jsonapi_resources :invitations, only: %i[index show create update]

  # Metrics (custom summary endpoint, read-only)
  get 'metrics/summary', to: 'metrics_summary#show'

  # Pages
  jsonapi_resources :pages

  # Navigation
  jsonapi_resources :navigation_areas, only: %i[index show create update]
  jsonapi_resources :navigation_items

  # Geography (read-only)
  jsonapi_resources :geography_continents, only: %i[index show]
  jsonapi_resources :geography_countries, only: %i[index show]
  jsonapi_resources :geography_states, only: %i[index show]
  jsonapi_resources :geography_regions, only: %i[index show]
  jsonapi_resources :geography_settlements, only: %i[index show]

  # Uploads
  jsonapi_resources :uploads

  # Joatu Exchange
  jsonapi_resources :joatu_offers
  jsonapi_resources :joatu_requests
  jsonapi_resources :joatu_agreements, only: %i[index show create update]
  post 'joatu_agreements/:id/accept', to: 'joatu_agreements#accept'
  post 'joatu_agreements/:id/reject', to: 'joatu_agreements#reject'

  # Webhook management (outbound subscriptions)
  jsonapi_resources :webhook_endpoints
  post 'webhook_endpoints/:id/test', to: 'webhook_endpoints#test'

  # Inbound webhooks (receive events from external systems)
  post 'webhooks/receive', to: 'webhooks#receive'
end
