# File outbound SMTP copies into the Sent mailbox (triggered by Exim LMTP copy).
require ["fileinto"];

if header :contains "X-Save-Copy" "sent" {
  fileinto "Sent";
  stop;
}
