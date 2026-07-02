# frozen_string_literal: true

# Data migration: re-encrypt existing plaintext borgberry_did values now that
# Person#borgberry_did uses ActiveRecord::Encryption (deterministic: true).
#
# Before this migration runs, any Person rows written before the encrypts
# declaration was added have plaintext borgberry_did values.  Calling
# update_columns triggers no validations or callbacks — it writes the
# AR-encrypted ciphertext directly over the plaintext.
#
# This migration is idempotent: rows whose borgberry_did is nil are skipped,
# and rows already encrypted (ciphertext starts with the AR::Encryption header)
# are written back as-is (AR::Encryption decrypts + re-encrypts transparently).
#
# Run time: O(n) where n = persons with a borgberry_did.  Expected to be a
# small set (one per registered operator).  Safe to run online — the write is
# per-row and does not lock the table.
class ReencryptPersonBorgberryDid < ActiveRecord::Migration[7.2]
  def up
    BetterTogether::Person.where.not(borgberry_did: nil).find_each do |person|
      # Reading person.borgberry_did decrypts (or returns plaintext if not yet
      # encrypted).  update_columns writes the AR-encrypted ciphertext.
      person.update_columns(borgberry_did: person.borgberry_did)
    rescue ActiveRecord::Encryption::Errors::Decryption => e
      Rails.logger.warn("[ReencryptPersonBorgberryDid] skipping person #{person.id}: #{e.message}")
    end
  end

  def down
    # Not reversible — decrypting back to plaintext would defeat the purpose.
    raise ActiveRecord::IrreversibleMigration
  end
end
