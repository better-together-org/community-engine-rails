import consumer from "channels/consumer";
import { displayFlashMessage, updateUnreadNotifications } from "better_together/notifications";
import DevicePermissionsController from "controllers/better_together/device_permissions_controller";

consumer.subscriptions.create("BetterTogether::NotificationsChannel", {
  connected() {
    // console.log("notifications channel connected");
  },
  received(data) {
    const identifier = data["identifier"];
    if (!identifier || window.location.href.includes(identifier)) {
      return;
    }

    function showInfoFlashMessage(data) {
      let messageContent = `${data["title"]} - ${data["body"]}`;
      if (data["url"]) {
        messageContent = `<a href="${data["url"]}" target="_blank" rel="noopener" style="color:inherit;">${messageContent}</a>`;
      }
      displayFlashMessage("info", messageContent);
      if (data["unread_count"] !== undefined) {
        updateUnreadNotifications(data["unread_count"]);
      }
    }

    if (Notification.permission === "default") {
      showInfoFlashMessage(data);
      const devicePermissions = new DevicePermissionsController();
      devicePermissions.requestNotifications();
      return;
    }

    if (Notification.permission === "granted") {
      showInfoFlashMessage(data);
      const notification = new Notification(data["title"], { body: data["body"] });
      if (data["url"]) {
        notification.onclick = function (event) {
          event.preventDefault();
          window.open(data["url"], identifier || "_blank");
        };
      }
    }
  },
});
