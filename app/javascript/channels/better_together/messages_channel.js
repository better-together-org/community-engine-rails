import consumer from "../consumer"

consumer.subscriptions.create("MessagesChannel", {
  received(data) {
    const messagesContainer = document.getElementById('messages')
    messagesContainer.innerHTML += `<p><strong>${data.person}:</strong> ${data.content} <span>${data.created_at}</span></p>`
  }
})
