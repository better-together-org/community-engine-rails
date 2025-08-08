import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="message-visibility"
export default class extends Controller {
	connect() {
		console.log('message visibility controller connected')
		const rootElement = document.getElementById('conversation-messages');

		const observer = new IntersectionObserver(this.onIntersect, {
			root: rootElement,
			rootMargin: '0px',
			threshold: 1.0
		});

		observer.observe(this.element);
		this.observer = observer;
	}

	onIntersect = (entries, observer) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				const messageId = this.element.dataset.messageId;
				console.log(`Message ${messageId} is on screen.`);

				this.markAsRead(messageId);

				observer.unobserve(this.element);
			}
		});
	}

	markAsRead(messageId) {
		fetch(`/en/notifications/mark_record_as_read`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'X-CSRF-Token': this.getCSRFToken()
			},
			body: JSON.stringify({
				record_id: messageId
			})
		})
		.then(response => {
			if (response.ok) {
				console.log(`Notification for message ${messageId} marked as read.`)
			} else {
				console.error(`Failed to mark notification for message ${messageId} as read.`)
			}
		})
	}

	getCSRFToken() {
		const tokenElement = document.querySelector("meta[name='csrf-token']")
		return tokenElement ? tokenElement.getAttribute("content") : ""
	}
}
