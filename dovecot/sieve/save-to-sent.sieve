# File outbound SMTP copies into the Sent mailbox (triggered by Exim LMTP copy).
require ["fileinto", "imap4flags"];

if header :contains "X-Save-Copy" "sent" {
  fileinto :flags "\\Seen" "Sent";
  stop;
}
