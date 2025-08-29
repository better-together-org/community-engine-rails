# Agreements

An Agreement is a simple confirmation between one Offer and one Request.

- Easy idea: When an Offer and a Request match, you can create an Agreement to say “Yes, let’s do this.”
- Status shows where things are at: `pending`, `accepted`, or `rejected`.

## How to Make or Respond to an Agreement

1. From a Request or Offer, use the “Create Agreement” button.
2. The Agreement page shows both sides — what’s being offered, and what’s needed.
3. If you’re involved, you’ll see buttons to Accept or Reject.
4. Once accepted, both the Offer and Request are marked as closed.

That’s it — a small, clear step that keeps everyone on the same page.

---

<details>
<summary>Bonus: How Agreements work behind the scenes</summary>

- An Agreement connects `offer_id` and `request_id` and keeps a `status`.
- When status changes, both creators can be notified.
- You can only accept/reject if you’re one of the two participants (or a platform manager).
- The Agreement URL is used in notifications; when you open it, your related notifications are marked as read.
- Routes include member actions: `/agreements/:id/accept` and `/agreements/:id/reject` (POST).
</details>

