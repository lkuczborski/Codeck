const root = document.documentElement;
const systemAppearance = window.matchMedia("(prefers-color-scheme: dark)");
const appearanceButtons = [...document.querySelectorAll("button[data-color-mode]")];

const applyAppearance = (mode) => {
    const scheme = mode === "system" ? (systemAppearance.matches ? "dark" : "light") : mode;
    root.dataset.colorMode = mode;
    root.dataset.colorScheme = scheme;
    document.querySelector('meta[name="theme-color"]').content = scheme === "dark" ? "#0e1016" : "#f8f9fc";
    appearanceButtons.forEach((button) => {
        button.setAttribute("aria-pressed", String(button.dataset.colorMode === mode));
    });
};

applyAppearance(root.dataset.colorMode || "system");
document.querySelector("[data-appearance]").hidden = false;
appearanceButtons.forEach((button) => {
    button.addEventListener("click", () => {
        const mode = button.dataset.colorMode;
        applyAppearance(mode);
        try { localStorage.setItem("codeck-color-mode", mode); } catch { /* The theme still works without storage. */ }
    });
});
systemAppearance.addEventListener("change", () => {
    if (root.dataset.colorMode === "system") applyAppearance("system");
});
window.addEventListener("storage", (event) => {
    if (event.key !== "codeck-color-mode" && event.key !== null) return;
    const mode = ["light", "dark", "system"].includes(event.newValue) ? event.newValue : "system";
    applyAppearance(mode);
});

const menuToggle = document.querySelector("[data-menu-toggle]");
const mobileMenu = document.querySelector("#mobile-menu");
const closeMenu = (restoreFocus = false) => {
    mobileMenu.hidden = true;
    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.textContent = "Menu";
    if (restoreFocus) menuToggle.focus();
};
menuToggle.hidden = false;
menuToggle.addEventListener("click", () => {
    const isOpen = menuToggle.getAttribute("aria-expanded") === "true";
    if (isOpen) return closeMenu();
    mobileMenu.hidden = false;
    menuToggle.setAttribute("aria-expanded", "true");
    menuToggle.textContent = "Close";
});
mobileMenu.querySelectorAll("a").forEach((link) => link.addEventListener("click", () => closeMenu()));
document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !mobileMenu.hidden) closeMenu(true);
});
window.matchMedia("(min-width: 921px)").addEventListener("change", (event) => {
    if (event.matches) closeMenu();
});

const themeStudio = document.querySelector(".theme-studio");
const themeButtons = [...document.querySelectorAll("button[data-deck-theme]")];
const selectTheme = (button) => {
    const theme = button.dataset.deckTheme;
    themeStudio.dataset.deckTheme = theme;
    document.querySelector("[data-source-theme]").textContent = theme;
    document.querySelector("[data-theme-name]").textContent = theme.toUpperCase();
    themeButtons.forEach((candidate) => candidate.setAttribute("aria-pressed", String(candidate === button)));
};
themeButtons.forEach((button, index) => {
    button.addEventListener("click", () => selectTheme(button));
    button.addEventListener("keydown", (event) => {
        let nextIndex;
        if (event.key === "ArrowRight") nextIndex = (index + 1) % themeButtons.length;
        if (event.key === "ArrowLeft") nextIndex = (index - 1 + themeButtons.length) % themeButtons.length;
        if (event.key === "Home") nextIndex = 0;
        if (event.key === "End") nextIndex = themeButtons.length - 1;
        if (nextIndex === undefined) return;
        event.preventDefault();
        themeButtons[nextIndex].focus();
        selectTheme(themeButtons[nextIndex]);
    });
});

const copyStatus = document.querySelector("[data-copy-status]");
document.querySelectorAll("[data-copy]").forEach((button) => {
    let resetTimer;
    button.hidden = false;
    button.addEventListener("click", async () => {
        const source = document.getElementById(button.dataset.copy);
        let copied = false;
        try {
            await navigator.clipboard.writeText(source.textContent);
            copied = true;
        } catch {
            // Keep the source selected when clipboard access is unavailable.
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(source);
            selection.removeAllRanges();
            selection.addRange(range);
        }
        clearTimeout(resetTimer);
        button.querySelector("span").textContent = copied ? "Copied" : "Selected";
        copyStatus.textContent = copied ? "Copied to clipboard." : "Text selected. Use your browser’s copy command.";
        resetTimer = setTimeout(() => { button.querySelector("span").textContent = "Copy"; }, 2200);
    });
});
