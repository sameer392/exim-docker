document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-copy]");
  if (!button) return;

  const text = button.getAttribute("data-copy");
  if (!text) return;

  navigator.clipboard.writeText(text).then(() => {
    const label = button.getAttribute("aria-label") || "Copy";
    button.classList.add("copied");
    button.setAttribute("aria-label", "Copied");
    setTimeout(() => {
      button.classList.remove("copied");
      button.setAttribute("aria-label", label);
    }, 1500);
  });
});
