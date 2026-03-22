# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

if Rails.env.test?
  Rails.application.config.session_store :cookie_store,
                                         key: '_dummy_session',
                                         same_site: :lax,
                                         secure: false
else
  Rails.application.config.session_store :cookie_store, key: '_dummy_session'
end
