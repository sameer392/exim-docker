function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) {
    return navigator.clipboard.writeText(text);
  }

  return new Promise((resolve, reject) => {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.top = "0";
    ta.style.left = "-9999px";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    ta.setSelectionRange(0, ta.value.length);
    try {
      const ok = document.execCommand("copy");
      document.body.removeChild(ta);
      if (ok) resolve();
      else reject(new Error("Copy command failed"));
    } catch (err) {
      document.body.removeChild(ta);
      reject(err);
    }
  });
}

function flashCopied(button) {
  const label = button.getAttribute("aria-label") || "Copy";
  button.classList.add("copied");
  button.setAttribute("aria-label", "Copied");
  button.title = "Copied";
  setTimeout(() => {
    button.classList.remove("copied");
    button.setAttribute("aria-label", label);
    button.title = label;
  }, 1500);
}

document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-copy]");
  if (!button) return;

  const field = button.closest(".copy-field");
  const fromCode = field && field.querySelector("code");
  const text = (button.getAttribute("data-copy") || (fromCode && fromCode.textContent) || "").trim();
  if (!text) return;

  copyText(text)
    .then(() => flashCopied(button))
    .catch(() => {
      // Last resort: select the visible value so the user can Ctrl+C
      if (fromCode) {
        const range = document.createRange();
        range.selectNodeContents(fromCode);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
        button.title = "Selected — press Ctrl+C";
      } else {
        window.prompt("Copy this value:", text);
      }
    });
});
