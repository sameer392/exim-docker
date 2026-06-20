(function () {
  var url = new URL(window.location.href);
  if (!url.searchParams.has("msg") && !url.searchParams.has("error")) {
    return;
  }
  url.searchParams.delete("msg");
  url.searchParams.delete("error");
  var clean =
    url.pathname +
    (url.searchParams.toString() ? "?" + url.searchParams.toString() : "") +
    url.hash;
  history.replaceState(null, "", clean);
})();
