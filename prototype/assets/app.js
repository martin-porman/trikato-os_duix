document.documentElement.classList.add("page-ready");

const currentFile = window.location.pathname.split("/").pop() || "index.html";

document.querySelectorAll(".main-nav a").forEach((link) => {
  const href = link.getAttribute("href");
  if (href === currentFile) {
    link.setAttribute("aria-current", "page");
  }
});

document.querySelectorAll("[data-filter-group]").forEach((bar) => {
  const chips = Array.from(bar.querySelectorAll(".filter-chip"));
  const targetSelector = bar.getAttribute("data-filter-target");
  if (!targetSelector) {
    return;
  }

  const items = Array.from(document.querySelectorAll(targetSelector));
  if (!chips.length || !items.length) {
    return;
  }

  const applyFilter = (value) => {
    chips.forEach((chip) => {
      chip.classList.toggle("is-active", chip.dataset.filterValue === value);
      chip.setAttribute("aria-pressed", String(chip.dataset.filterValue === value));
    });

    items.forEach((item) => {
      const tags = (item.dataset.filterTags || "").split(/\s+/).filter(Boolean);
      const shouldShow = value === "all" || tags.includes(value);
      item.classList.toggle("is-hidden", !shouldShow);
    });
  };

  chips.forEach((chip) => {
    chip.addEventListener("click", () => applyFilter(chip.dataset.filterValue || "all"));
  });

  const initial = chips.find((chip) => chip.classList.contains("is-active")) || chips[0];
  applyFilter(initial.dataset.filterValue || "all");
});
