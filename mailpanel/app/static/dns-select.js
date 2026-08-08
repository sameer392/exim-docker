(function () {
  function wireSelect(selectId, blockSelector) {
    const select = document.getElementById(selectId);
    if (!select) return;

    const blocks = Array.from(document.querySelectorAll(blockSelector));

    function showDomain(domain, scrollTo) {
      blocks.forEach((block) => {
        block.hidden = block.getAttribute("data-domain") !== domain;
      });
      if (select.value !== domain) {
        select.value = domain;
      }
      if (scrollTo) {
        const el = document.getElementById(scrollTo);
        if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    }

    select.addEventListener("change", () => showDomain(select.value, null));

    const params = new URLSearchParams(window.location.search);
    const fromUrl = params.get("domain");
    if (fromUrl && blocks.some((b) => b.getAttribute("data-domain") === fromUrl)) {
      showDomain(fromUrl, null);
    } else {
      showDomain(select.value, null);
    }

    return showDomain;
  }

  const showDns = wireSelect("dns-domain-select", ".dns-domain-block[data-domain]");
  wireSelect("smtp-allow-domain-select", ".smtp-allow-block[data-domain]");

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-show-dns]");
    if (!button || !showDns) return;
    const domain = button.getAttribute("data-show-dns");
    if (!domain) return;
    showDns(domain, "dns-section");
  });
})();
