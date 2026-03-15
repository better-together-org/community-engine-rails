// e2e_session_controller.js
// Application-wide Stimulus controller (once per page for conversation-enabled users).
// Generates Signal Protocol identity keys on first visit and registers them with the server.
// Must be connected to a non-visible element (e.g. <div data-controller="better-together--e2e-session">)
// with data attributes providing the current user's person ID.
//
// Required data attributes:
//   data-person-id        — the current user's BetterTogether::Person ID
//
// Optional data attributes:
//   data-base-url         — API base URL (default: '')

import { Controller } from "@hotwired/stimulus"
import {
  generateIdentity,
  hasLocalIdentity,
  registerPrekeys,
  fetchPrekeyBundle
} from "community_engine_js"

export default class extends Controller {
  static values = {
    personId: String,
    baseUrl:  { type: String, default: '' }
  }

  async connect() {
    if (!this.personIdValue) return

    try {
      await this.ensureKeysRegistered()
    } catch (err) {
      console.error('[E2E] Key registration error:', err)
    }
  }

  async ensureKeysRegistered() {
    const alreadyLocal = await hasLocalIdentity()

    if (!alreadyLocal) {
      // First time: generate keys and register with server
      const bundle = await generateIdentity()
      await registerPrekeys(this.personIdValue, bundle, { baseUrl: this.baseUrlValue })
      console.info('[E2E] Identity keys generated and registered.')
      return
    }

    // Keys exist locally. Check if the server also has them (e.g. new browser or cleared storage).
    const serverBundle = await fetchPrekeyBundle(this.personIdValue, { baseUrl: this.baseUrlValue })
    if (!serverBundle) {
      // Server has no record — re-register from local identity
      const bundle = await generateIdentity()
      await registerPrekeys(this.personIdValue, bundle, { baseUrl: this.baseUrlValue })
      console.info('[E2E] Re-registered identity keys with server.')
    }
  }
}
