(function () {
  const select = document.getElementById("dns-domain-select");
  if (!select) return;

  const blocks = Array.from(document.querySelectorAll(".dns-domain-block[data-domain]"));

  function showDomain(domain, scroll) {
    blocks.forEach((block) => {
      block.hidden = block.getAttribute("data-domain") !== domain;
    });
    if (select.value !== domain) {
      select.value = domain;
    }
    if (scroll) {
      const section = document.getElementById("dns-section");
      if (section) section.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  select.addEventListener("change", () => {
    showDomain(select.value, false);
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-show-dns]");
    if (!button) return;
    const domain = button.getAttribute("data-show-dns");
    if (!domain) return;
    showDomain(domain, true);
  });

  // Honor ?domain=example.com in the URL if present
  const params = new URLSearchParams(window.location.search);
  const fromUrl = params.get("domain");
  if (fromUrl && blocks.some((b) => b.getAttribute("data-domain") === fromUrl)) {
    showDomain(fromUrl, false);
  } else {
    showDomain(select.value, false);
  }
})();
