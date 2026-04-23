# frozen_string_literal: true

# API v1 resource routes

namespace :v1 do # rubocop:disable Metrics/BlockLength
  # People
  get 'people/me', to: 'people#me'
  get 'me/data_exports', to: 'person_data_exports#index'
  post 'me/data_exports', to: 'person_data_exports#create'
  get 'me/data_exports/:id', to: 'person_data_exports#show'
  get 'me/deletion_requests', to: 'person_deletion_requests#index'
  post 'me/deletion_requests', to: 'person_deletion_requests#create'
  delete 'me/deletion_requests/:id', to: 'person_deletion_requests#destroy'
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

  # E2E encryption: prekey management + encrypted key backup
  resources :people, only: [] do
    member do
      get  :prekey_bundle,    to: 'prekeys#prekey_bundle'
      put  :register_prekeys, to: 'prekeys#register_prekeys'
      get  :key_backup,       to: 'prekeys#key_backup'
      put  :key_backup,       to: 'prekeys#save_key_backup'
    end
  end

  # E2E encryption: conversation-scoped participant prekey bundles
  resources :conversations, only: [] do
    member do
      get :participant_prekey_bundles, to: 'conversations#participant_prekey_bundles'
    end
  end

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

  # Pages and Content Blocks
  jsonapi_resources :pages
  jsonapi_resources :authorships
  jsonapi_resources :page_blocks

  # Content Blocks (all STI types — filter by page_id or type)
  jsonapi_resources :blocks

  # Navigation
  jsonapi_resources :navigation_areas, only: %i[index show create update]
  jsonapi_resources :navigation_items
  jsonapi_resources :robots, only: %i[index show create update]

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
  post 'joatu_agreements/:id/cancel', to: 'joatu_agreements#cancel'
  post 'joatu_agreements/:id/reject', to: 'joatu_agreements#reject'

  # Membership requests — create is public (unauthenticated); read/manage require auth
  jsonapi_resources :membership_requests, only: %i[index show create destroy]

  # C3 Community Contribution Token (borgberry fleet integration)
  namespace :c3 do
    post 'contributions',   to: 'contributions#create'
    get  'contributions',   to: 'contributions#index'
    get  'balance',         to: 'contributions#balance'
    get  'network_balance', to: 'contributions#network_balance'
  end

  # Borgberry identity — returns this node's borgberry DID and person identity
  namespace :borgberry do
    get 'profile', to: 'profile#show'
  end

  # Fleet node registry (borgberry fleet agent registration + heartbeat)
  namespace :fleet do
    resources :nodes, param: :node_id, only: %i[index show create] do
      member do
        post :heartbeat
      end
    end
  end

  # Webhook management (outbound subscriptions)
  jsonapi_resources :webhook_endpoints
  post 'webhook_endpoints/:id/test', to: 'webhook_endpoints#test'

  # Inbound webhooks (receive events from external systems)
  post 'webhooks/receive', to: 'webhooks#receive'

  # Host app extension point — add app-specific JSONAPI resources to this namespace.
  # Configure in host app (e.g. config/initializers/better_together.rb):
  #   BetterTogether.api_v1_routes_extension = proc do
  #     jsonapi_resources :wayfinders
  #     jsonapi_resources :venues
  #   end
  instance_exec(&BetterTogether.api_v1_routes_extension) if BetterTogether.api_v1_routes_extension
end
