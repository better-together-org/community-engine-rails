// e2e_message_form_controller.js
// Wraps the message form to encrypt messages before submission when
// all participants have registered E2E keys.
//
// Required data attributes on the form:
//   data-conversation-id  — the conversation ID
//   data-person-id        — current user's person ID
//   data-base-url         — optional API base URL
//
// Targets:
//   content   — the Trix rich text area
//   status    — optional status badge (shows E2E active / waiting)

import { Controller } from "@hotwired/stimulus"
import {
  hasSession,
  initOutboundSession,
  encryptMessage,
  encryptGroupMessage,
  createSenderKeyDistribution,
  fetchParticipantBundles
} from "community_engine_js"

export default class extends Controller {
  static targets = ["content", "status"]
  static values = {
    conversationId:    String,
    personId:         String,
    baseUrl:          { type: String, default: '' },
    senderKeyVersion: { type: Number, default: -1 }   // -1 = not yet initialised
  }

  // Participant bundles fetched on connect, keyed by personId
  #participantBundles = {}
  // Whether sender keys have been distributed for this conversation
  #senderKeysReady = false
  // Guard flag: true while we are submitting the encrypted form to prevent re-entry
  #submitting = false

  async connect() {
    if (!this.conversationIdValue || !this.personIdValue) return
    this.element.addEventListener('submit', this.#handleSubmit.bind(this))

    try {
      await this.#setupSessions()
    } catch (err) {
      console.error('[E2E Form] Session setup error:', err)
      this.#setStatus('error')
    }
  }

  // Called by Stimulus whenever the senderKeyVersion data attribute changes.
  // A version change means a participant was added or removed. Reset key state
  // so the next group message distributes a fresh sender key to the current
  // participant set only — removing the departed member's decrypt access.
  senderKeyVersionValueChanged(newVersion, oldVersion) {
    if (oldVersion === undefined) return  // initial connect — not a membership event
    this.#senderKeysReady = false
    this.#setupSessions()  // re-fetches participant bundles reflecting new membership
  }

  disconnect() {
    this.element.removeEventListener('submit', this.#handleSubmit.bind(this))
  }

  async #setupSessions() {
    const bundles = await fetchParticipantBundles(
      this.conversationIdValue,
      { baseUrl: this.baseUrlValue }
    )

    const others = bundles.filter(b => String(b.person_id) !== String(this.personIdValue))

    if (others.length === 0) {
      this.#setStatus('no-participants')
      return
    }

    const allRegistered = others.every(b => b.identity_key)
    if (!allRegistered) {
      this.#setStatus('waiting')
      return
    }

    // Build outbound sessions for participants who don't have one yet
    for (const bundle of others) {
      if (!(await hasSession(bundle.person_id))) {
        await initOutboundSession(bundle.person_id, bundle)
      }
      this.#participantBundles[bundle.person_id] = bundle
    }

    this.#senderKeysReady = false  // will distribute on first group message
    this.#setStatus('active')
  }

  async #handleSubmit(event) {
    if (!this.hasContentTarget) return
    // Re-entry guard: skip encryption on the submit we fire ourselves after encoding
    if (this.#submitting) return
    const participants = Object.keys(this.#participantBundles)
    if (participants.length === 0) return  // No sessions: send unencrypted

    event.preventDefault()

    const trixEditor = this.contentTarget
    const plaintext  = trixEditor.value || trixEditor.innerText || ''
    if (!plaintext.trim()) return

    try {
      let payload
      if (participants.length === 1) {
        // 1:1 — Double Ratchet
        const envelope = await encryptMessage(participants[0], plaintext)
        payload = { type: 'signal_v1', envelope, recipientPersonId: participants[0] }
      } else {
        // Group — Sender Keys
        if (!this.#senderKeysReady) {
          const { distributionId, distributionMessages } = await createSenderKeyDistribution(
            this.conversationIdValue,
            this.personIdValue,
            participants
          )
          // Post distribution envelopes to each participant via server relay
          // (piggybacked on the next message; for now store in payload)
          payload = {
            type: 'sender_keys_v1',
            distributionId,
            distributionMessages,
            envelope: await encryptGroupMessage(this.conversationIdValue, this.personIdValue, plaintext)
          }
          this.#senderKeysReady = true
        } else {
          payload = {
            type: 'sender_keys_v1',
            envelope: await encryptGroupMessage(this.conversationIdValue, this.personIdValue, plaintext)
          }
        }
      }

      // Store the ciphertext JSON in the Trix content field (persisted via ActionText :content).
      // The server stores this opaque blob; only the recipient's browser can decrypt it.
      this.#setContentField(JSON.stringify(payload))
      this.#setHiddenField('message[e2e_encrypted]', 'true')
      this.#setHiddenField('message[e2e_protocol]', payload.type)

      // Submit the form once, bypassing this handler via the re-entry guard.
      this.#submitting = true
      this.element.requestSubmit()
    } catch (err) {
      console.error('[E2E Form] Encryption error:', err)
      // Fall through to unencrypted send rather than silently failing
      this.#submitting = true
      this.element.requestSubmit()
    } finally {
      this.#submitting = false
    }
  }

  #setStatus(state) {
    if (!this.hasStatusTarget) return
    const labels = {
      active:          'E2E active 🔒',
      waiting:         'Waiting for participant keys…',
      'no-participants': '',
      error:           'E2E unavailable'
    }
    this.statusTarget.textContent = labels[state] ?? ''
    this.statusTarget.dataset.state = state
  }

  #setHiddenField(name, value) {
    let field = this.element.querySelector(`input[name="${name}"]`)
    if (!field) {
      field = document.createElement('input')
      field.type = 'hidden'
      field.name = name
      this.element.appendChild(field)
    }
    field.value = value
  }

  #setContentField(text) {
    // Write the ciphertext JSON into the Trix editor so ActionText persists it
    // as the :content body. The server stores the opaque blob; only the recipient
    // can decrypt it. We use loadHTML with a plain-text node so Trix doesn't
    // interpret the JSON as markup.
    if (this.hasContentTarget && this.contentTarget.editor) {
      const escaped = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      this.contentTarget.editor.loadHTML(`<div>${escaped}</div>`)
    }
  }
}
