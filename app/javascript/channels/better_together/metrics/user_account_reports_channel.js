import consumer from "channels/consumer";
import { createDebug } from "better_together/debugger";

// Create debug instance for this channel
const debug = createDebug('UserAccountReportsChannel', { debug: true });

consumer.subscriptions.create("BetterTogether::Metrics::UserAccountReportsChannel", {
  connected() {
    // Connected to user account reports channel
    debug.log("Connected to channel");
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    debug.log("Disconnected from channel");
  },

  received(data) {
    // Called when data is broadcast on the channel
    debug.log("Received report update:", data);
    
    if (data.report_id && data.file_ready) {
      this.updateReportRow(data.report_id, data.download_url);
    }
  },

  updateReportRow(reportId, downloadUrl) {
    debug.log(`Updating report row for ID: ${reportId}`);
    
    // Try to find the row with a small delay to allow Turbo to finish rendering
    const findAndUpdate = () => {
      const row = document.getElementById(`user_account_report_${reportId}`);
      if (!row) {
        debug.error(`Could not find row with ID: user_account_report_${reportId}`);
        debug.log('Available report rows:', document.querySelectorAll('[id^="user_account_report_"]'));
        return false;
      }

      debug.log("Found row:", row);
      
      const actionsCell = row.querySelector('td:last-child');
      if (!actionsCell) {
        debug.error("Could not find actions cell");
        return false;
      }

      debug.log("Found actions cell:", actionsCell);

      // Find the generating status element
      const generatingStatus = actionsCell.querySelector('[data-report-generating]');
      if (!generatingStatus) {
        debug.error("Could not find generating status element");
        debug.log("Actions cell content:", actionsCell.innerHTML);
        return false;
      }

      debug.log("Found generating status, replacing with download button");

      // Replace with download button
      const downloadButton = document.createElement('a');
      downloadButton.href = downloadUrl;
      downloadButton.className = 'btn btn-primary btn-sm';
      downloadButton.setAttribute('data-turbo', 'false');
      downloadButton.innerHTML = '<i class="fas fa-download me-1"></i> Download';
      
      generatingStatus.replaceWith(downloadButton);
      
      debug.log("Successfully replaced generating status with download button");
      return true;
    };
    
    // Try immediately, then retry a few times if needed
    if (!findAndUpdate()) {
      setTimeout(() => {
        debug.log("Retrying after 100ms...");
        if (!findAndUpdate()) {
          setTimeout(() => {
            debug.log("Retrying after 300ms...");
            findAndUpdate();
          }, 200);
        }
      }, 100);
    }
  }
});
