// e2e_session_controller.js
// Application-wide Stimulus controller (once per page for conversation-enabled users).
// Generates Signal Protocol identity keys on first visit and registers them with the server.
// On a new device (no local keys), attempts to restore from the server-stored encrypted backup.
//
// Key backup model (passphrase-encrypted, Signal-style):
//   - On first identity generation: prompt for backup passphrase → encrypt bundle → upload.
//   - On prekey replenishment / signed prekey rotation: re-encrypt with in-session wrapping key
//     → upload silently (no re-prompt).
//   - On new device: server has backup blob → prompt for passphrase → decrypt → restore IndexedDB.
//   - Lost passphrase: hard loss. Old encrypted messages are permanently inaccessible.
//     User must generate a new identity (clearKeystore → generateIdentity → register).
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
  fetchPrekeyBundle,
  getLocalIdentity,
  getAllPreKeys,
  getAllSignedPreKeys,
  exportKeyBackup,
  importKeyBackup,
  clearV1SessionCache
} from "community_engine_js"

export default class extends Controller {
  static values = {
    personId: String,
    baseUrl:  { type: String, default: '' }
  }

  // In-memory wrapping key for silent re-backups during the session.
  // Set when the user enters their passphrase; cleared on disconnect/unload (never persisted).
  #sessionPassphrase = null

  // Bound beforeunload handler so it can be removed on disconnect.
  #boundClearCache = null

  // Minimum passphrase length for key backup (V7 defence-in-depth).
  static MIN_PASSPHRASE_LENGTH = 12

  async connect() {
    if (!this.personIdValue) return

    // V11 fix: clear v1 in-memory key cache on page unload so legacy session
    // keys do not live in the JS heap after the user navigates away or signs out.
    this.#boundClearCache = () => clearV1SessionCache()
    window.addEventListener('beforeunload', this.#boundClearCache)

    try {
      await this.ensureKeysReady()
    } catch (err) {
      console.error('[E2E] Key setup error:', err)
    }
  }

  disconnect() {
    clearV1SessionCache()
    if (this.#boundClearCache) {
      window.removeEventListener('beforeunload', this.#boundClearCache)
      this.#boundClearCache = null
    }
    this.#sessionPassphrase = null
  }

  async ensureKeysReady() {
    const alreadyLocal = await hasLocalIdentity()

    if (!alreadyLocal) {
      // No local keys — check if the server has a backup to restore from.
      const backup = await this.#fetchBackup()

      if (backup) {
        await this.#restoreFromBackup(backup)
      } else {
        // Truly new identity — generate, register, and create initial backup.
        await this.#generateAndRegister()
      }
      return
    }

    // Keys exist locally. Ensure the server also has them.
    const serverBundle = await fetchPrekeyBundle(this.personIdValue, { baseUrl: this.baseUrlValue })
    if (!serverBundle) {
      const bundle = await generateIdentity()
      await registerPrekeys(this.personIdValue, bundle, { baseUrl: this.baseUrlValue })
      console.info('[E2E] Re-registered identity keys with server.')
    }
  }

  // ── New identity flow ────────────────────────────────────────────────────────

  async #generateAndRegister() {
    const bundle = await generateIdentity()
    await registerPrekeys(this.personIdValue, bundle, { baseUrl: this.baseUrlValue })
    console.info('[E2E] Identity keys generated and registered.')

    const passphrase = await this.#promptPassphraseForBackup()
    if (passphrase) {
      this.#sessionPassphrase = passphrase
      await this.#uploadBackup(passphrase)
      console.info('[E2E] Key backup uploaded.')
    } else {
      console.warn('[E2E] Key backup skipped — passphrase not provided. ' +
        'Encrypted messages will not be recoverable on other devices.')
    }
  }

  // ── Restore flow ─────────────────────────────────────────────────────────────

  async #restoreFromBackup(backup) {
    const passphrase = await this.#promptPassphraseForRestore()
    if (!passphrase) {
      console.warn('[E2E] Restore skipped — generating fresh identity instead.')
      await this.#generateAndRegister()
      return
    }

    try {
      await importKeyBackup(passphrase, backup.blob, backup.salt)
      this.#sessionPassphrase = passphrase
      console.info('[E2E] Key backup restored successfully.')

      // Re-register public keys with server from restored state (prekey API expects public material).
      const restoredBundle = await this.#buildRegistrationBundle()
      if (restoredBundle) {
        await registerPrekeys(this.personIdValue, restoredBundle, { baseUrl: this.baseUrlValue })
        console.info('[E2E] Re-registered restored keys with server.')
      }
    } catch (err) {
      console.error('[E2E] Backup restore failed (wrong passphrase or corrupt backup):', err)
      const retry = await this.#confirmFreshIdentity()
      if (retry) {
        await this.#generateAndRegister()
      }
    }
  }

  // ── Backup upload ────────────────────────────────────────────────────────────

  async #uploadBackup(passphrase) {
    const { blob, salt } = await exportKeyBackup(passphrase)
    const res = await fetch(
      `${this.baseUrlValue}/api/v1/people/${this.personIdValue}/key_backup`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content ?? ''
        },
        credentials: 'same-origin',
        body: JSON.stringify({ blob, salt })
      }
    )
    if (!res.ok) {
      const body = await res.text()
      throw new Error(`[E2E] Key backup upload failed: HTTP ${res.status} — ${body}`)
    }
  }

  // ── Backup fetch ─────────────────────────────────────────────────────────────

  async #fetchBackup() {
    const res = await fetch(
      `${this.baseUrlValue}/api/v1/people/${this.personIdValue}/key_backup`,
      { method: 'GET', credentials: 'same-origin' }
    )
    if (res.status === 404) return null
    if (!res.ok) return null
    const json = await res.json()
    return json.data  // { blob, salt, updated_at }
  }

  // ── Registration bundle from restored keystore ───────────────────────────────

  async #buildRegistrationBundle() {
    const [identity, signedPrekeys, prekeys] = await Promise.all([
      getLocalIdentity(),
      getAllSignedPreKeys(),
      getAllPreKeys()
    ])

    if (!identity) return null

    const spk = signedPrekeys[signedPrekeys.length - 1]
    return {
      registration_id:  identity.registrationId,
      identity_key:     identity.publicKey,
      signed_prekey:    spk ? { id: spk.id, public_key: spk.publicKey, signature: spk.signature } : null,
      one_time_prekeys: prekeys.map(pk => ({ id: pk.id, public_key: pk.publicKey }))
    }
  }

  // ── UI prompts (Bootstrap modal via e2e:request-passphrase / e2e:request-confirm events) ──

  async #promptPassphraseForBackup() {
    const min = this.constructor.MIN_PASSPHRASE_LENGTH
    return new Promise(resolve => {
      document.dispatchEvent(new CustomEvent('e2e:request-passphrase', {
        detail: {
          message:   `Set a backup passphrase (min ${min} chars). Leave blank to skip.`,
          showInput: true,
          minLength: min,
          resolve
        }
      }))
    })
  }

  async #promptPassphraseForRestore() {
    return new Promise(resolve => {
      document.dispatchEvent(new CustomEvent('e2e:request-passphrase', {
        detail: {
          message:   'Encrypted key backup found. Enter your passphrase to restore, or leave blank to generate a fresh identity.',
          showInput: true,
          minLength: 0,
          resolve
        }
      }))
    })
  }

  async #confirmFreshIdentity() {
    return new Promise(resolve => {
      document.dispatchEvent(new CustomEvent('e2e:request-confirm', {
        detail: {
          message:   'Restore failed. Generate a fresh identity? Old encrypted messages will remain inaccessible.',
          showInput: false,
          resolve:   v => resolve(v !== null)
        }
      }))
    })
  }
}
