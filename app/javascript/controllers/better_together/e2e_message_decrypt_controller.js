// e2e_message_decrypt_controller.js
// Attached to each E2E message bubble. Decrypts the ciphertext and replaces the
// placeholder text with the decrypted plaintext.
//
// Required data attributes:
//   data-ciphertext-payload  — JSON-stringified { type, envelope, ... }
//   data-sender-person-id    — the message sender's person ID
//   data-conversation-id     — the conversation ID (needed for Sender Keys)

import { Controller } from "@hotwired/stimulus"
import {
  decryptMessage,
  decryptGroupMessage,
  processSenderKeyDistribution
} from "community_engine_js"

export default class extends Controller {
  static values = {
    ciphertextPayload: String,
    senderPersonId:    String,
    conversationId:    String,
    decryptingText:    { type: String, default: '🔒 Decrypting…' },
    errorText:         { type: String, default: '[Could not decrypt message]' }
  }

  async connect() {
    if (!this.ciphertextPayloadValue) return

    this.element.textContent = this.decryptingTextValue

    try {
      const payload = JSON.parse(this.ciphertextPayloadValue)
      const plaintext = await this.#decrypt(payload)
      this.element.textContent = plaintext
    } catch (err) {
      console.warn('[E2E Decrypt] Failed:', err)
      this.element.textContent = this.errorTextValue
    }
  }

  // V7 fix: clear plaintext from DOM when the controller disconnects so
  // decrypted message content does not linger for the page lifetime.
  disconnect() {
    this.element.textContent = ''
  }

  async #decrypt(payload) {
    if (payload.type === 'signal_v1') {
      return decryptMessage(this.senderPersonIdValue, payload.envelope)
    }

    if (payload.type === 'sender_keys_v1') {
      // If this message also carries a SenderKey distribution, process it first
      if (payload.distributionMessages) {
        // CE JS library produces { personId, envelope } — not recipientPersonId
        const myDistribution = payload.distributionMessages.find(
          m => String(m.personId) === String(this.#myPersonId())
        )
        if (myDistribution) {
          // The distribution message itself was Signal-encrypted for us
          const distributionJson = await decryptMessage(this.senderPersonIdValue, myDistribution.envelope)
          const distributionData = JSON.parse(distributionJson)
          await processSenderKeyDistribution(this.senderPersonIdValue, distributionData)
        }
      }
      return decryptGroupMessage(this.senderPersonIdValue, payload.envelope)
    }

    throw new Error(`Unknown E2E payload type: ${payload.type}`)
  }

  #myPersonId() {
    // Read the current user's person ID from the session meta tag or a data attribute on body
    return document.querySelector('meta[name="current-person-id"]')?.content ??
           document.body.dataset.personId ?? ''
  }
}
