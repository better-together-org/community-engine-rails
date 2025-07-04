import consumer from 'channels/consumer'

consumer.subscriptions.create("BetterTogether::NotificationsChannel", {
  connected() {
    console.log("notifications channel connected")
  },
  received(data) {
    console.log(Notification.permission, data);
    // Ask for notification permission if not already granted
    if (Notification.permission === "default") {
      Notification.requestPermission();
    }
    // If permission is granted, display the notification
    if (Notification.permission === "granted") {
      const notification = new Notification(data["title"], { body: data["body"] });
      if (data["url"]) {
        notification.onclick = function(event) {
          event.preventDefault();
          window.open(data["url"], (data["identifier"] || '_blank'));
        };
      }
    }
  }
})
