# File outbound SMTP copies into the Sent mailbox (triggered by Exim LMTP copy).
# info@hemochrom.com does not keep these copies: they are discarded instead.
require ["fileinto", "imap4flags", "envelope"];

if allof (header :contains "X-Save-Copy" "sent", envelope :is "to" "info@hemochrom.com") {
  discard;
  stop;
}

if header :contains "X-Save-Copy" "sent" {
  fileinto :flags "\\Seen" "Sent";
  stop;
}
