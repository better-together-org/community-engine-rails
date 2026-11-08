# Billing data encryption

Payment data is encrypted at rest with Rails Active Record Encryption. This page lists
what is encrypted, the rules every encrypted billing attribute follows (taken from the
Rails 8.1 Active Record Encryption guide and its implementation), and how to run keys.

## What is encrypted

| Data | Where |
|---|---|
| Raw processor event (customer e-mail, address, card brand and last four) | `pay_webhooks.event`, and `better_together_billing_events.payload` |
| Processor-supplied customer, charge, subscription, payment method and merchant data | `data`, `object` and `metadata` columns of the `pay_*` tables |
| Processor or exception text stored with an event | `better_together_billing_events.error_message` |

Not encrypted, because they are queried and reported on: ids, statuses, counters,
timestamps, amounts, currencies and plan catalog data (public product information).

Processor API keys and signing secrets are not stored in the database at all. They live in
environment variables or Rails credentials read by the processor extension gem.

## Rules

Every attribute is declared with `encrypts_billing_attribute`
(`BetterTogether::Billing::EncryptedAttributes`), which applies these rules in one place:

1. **`text` columns.** Ciphertext carries about 255 bytes of overhead and is Base64, so a
   `string(N)` column would need `N + 255` (four times as much for non-Western text).
   Use `text`. Avoid a column `limit`: Rails adds a plaintext length validation for one.
2. **Non-deterministic.** The guide recommends it unless you must query by the value.
   Billing never queries by ciphertext. If a later feature must look up by customer
   e-mail, use `deterministic: true, downcase: true` and never change that scheme:
   unique indexes depend on stable ciphertext, and the guide notes that key rotation is
   not supported for deterministic encryption.
3. **JSON is stored as `text`.** An encrypted value is not a JSON document, so a
   `json`/`jsonb` column cannot hold it. The macro declares `attribute name, :json`
   before `encrypts`; the guide warns the order matters.
4. **No database default.** A stored value equal to the column default is returned
   undecrypted. Give the default on the model (`default: -> { {} }`).
5. **No transition window.** `support_unencrypted_data` and `extend_queries` exist to
   migrate plaintext data. Billing never had any, so each attribute passes
   `support_unencrypted_data: false`. This also means the test environment's global
   setting cannot hide a forgotten `encrypts`.
6. **Column checks run when the schema loads**, not at class-load time, so booting
   without a database (asset precompile, `db:create`) still works. A column with a
   default, a limit or a non-text type raises `EncryptedAttributes::ColumnError`.

Also:

- Encrypted attributes show as `[FILTERED]` in `inspect` and in filtered parameters.
  Attribute readers and `as_json` still return plaintext, so never `render json:` an
  encrypted record; build the response from an explicit list of attributes.
- Compression is on by default for larger values; keep it.
- Loading a record with encrypted attributes decrypts them to check for changes, so lists
  and sweeps should `select` only the columns they need.
- `ActiveRecord::Encryption.without_encryption` and `protecting_encrypted_data` are for
  consoles and operations, never for application code.

## Keys

Generate keys with `bin/rails db:encryption:init` and store them in credentials or
environment variables (the host already needs them for other encrypted models):

```yaml
active_record_encryption:
  primary_key: ...
  deterministic_key: ...
  key_derivation_salt: ...
```

Losing a key makes the data it encrypted unreadable.

### Rotating the primary key

1. Add the new key at the **end** of `primary_key` (a list): the last key encrypts new
   data and every key is tried when decrypting.
2. Re-encrypt existing rows. Billing payloads are short-lived (events are redacted after
   `BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS`, default 30), so for events waiting one
   retention window is enough. For other tables run `record.encrypt` over the rows.
3. Remove the old key once nothing is encrypted with it.

Rotation is not supported for deterministic attributes.

## Pay's models

Pay's JSON columns are encrypted by concerns that Community Engine includes into Pay's
models (`BetterTogether::Billing::PayExtensions::EncryptedBillingData` and
`EncryptedWebhookEvent`, included from `config/initializers/billing_pay_extensions.rb`).
Pay reads these columns through `store_accessor` and plain attribute readers and never
with raw JSON SQL, and `store_accessor` finds its accessor through the attribute type
when it is called, so the encrypted attribute behaves like the original `jsonb` column.
`spec/models/better_together/billing/pay_extensions/` checks this, including that a
webhook can still be rehydrated and processed.
