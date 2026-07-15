document.documentElement.classList.add("js");

const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

const header = document.querySelector("[data-header]");
const menuToggle = document.querySelector("[data-menu-toggle]");
const mobileMenu = document.querySelector("[data-mobile-menu]");
const mainContent = document.querySelector("main");
const pageFooter = document.querySelector(".site-footer");

const updateHeader = () => {
    header?.toggleAttribute("data-scrolled", window.scrollY > 18);
};

const closeMenu = ({ restoreFocus = false } = {}) => {
    if (!menuToggle || !mobileMenu) return;

    mobileMenu.hidden = true;
    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.textContent = "Menu";
    document.body.classList.remove("menu-open");
    mainContent?.removeAttribute("inert");
    pageFooter?.removeAttribute("inert");

    if (restoreFocus) menuToggle.focus();
};

menuToggle?.addEventListener("click", () => {
    if (!mobileMenu) return;

    const isOpen = menuToggle.getAttribute("aria-expanded") === "true";
    if (isOpen) {
        closeMenu();
        return;
    }

    mobileMenu.hidden = false;
    menuToggle.setAttribute("aria-expanded", "true");
    menuToggle.textContent = "Close";
    document.body.classList.add("menu-open");
    mainContent?.setAttribute("inert", "");
    pageFooter?.setAttribute("inert", "");
    window.requestAnimationFrame(() => mobileMenu.querySelector("a")?.focus());
});

mobileMenu?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => closeMenu());
});

document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && menuToggle?.getAttribute("aria-expanded") === "true") {
        closeMenu({ restoreFocus: true });
    }
});

window.addEventListener("resize", () => {
    if (window.innerWidth > 980) closeMenu();
});

updateHeader();
window.addEventListener("scroll", updateHeader, { passive: true });

const runButton = document.querySelector("[data-run-demo]");
const demoStatus = document.querySelector("[data-demo-status]");
const demoOutput = document.querySelector("[data-demo-output]");
let demoTimers = [];

const streamedLines = [
    { text: "Three observable checks:", className: "stream-lead" },
    { text: "1. The prompt, constraints, and expected behavior are visible before the run." },
    { text: "2. The verification command is visible before the session starts." },
    { text: "3. The expected result stays on the slide for the next run." }
];

const appendDemoLine = ({ text, className }) => {
    if (!demoOutput) return;

    const line = document.createElement("p");
    line.textContent = text;
    if (className) line.className = className;
    demoOutput.append(line);
};

const finishDemo = () => {
    if (demoStatus) {
        demoStatus.textContent = "complete";
        demoStatus.dataset.state = "complete";
    }
    if (runButton) {
        runButton.disabled = false;
        runButton.textContent = "Replay sample";
    }
};

runButton?.addEventListener("click", () => {
    if (!demoOutput || !demoStatus || runButton.disabled) return;

    demoTimers.forEach(window.clearTimeout);
    demoTimers = [];
    demoOutput.replaceChildren();
    demoStatus.textContent = "running";
    demoStatus.dataset.state = "running";
    runButton.disabled = true;
    runButton.textContent = "Running…";

    if (prefersReducedMotion.matches) {
        streamedLines.forEach(appendDemoLine);
        finishDemo();
        return;
    }

    streamedLines.forEach((line, index) => {
        const timer = window.setTimeout(() => {
            appendDemoLine(line);
            if (index === streamedLines.length - 1) finishDemo();
        }, 420 * (index + 1));
        demoTimers.push(timer);
    });
});

const assistantDemo = document.querySelector("[data-assistant-demo]");
const proposalInputs = [...document.querySelectorAll("[data-proposal]")];
const selectionCount = document.querySelector("[data-selection-count]");
const applyProposalsButton = document.querySelector("[data-apply-proposals]");
const assistantSlide = assistantDemo?.querySelector(".assistant-slide");
const slideState = document.querySelector("[data-slide-state]");
const slideTitle = document.querySelector("[data-slide-title]");
const slideKicker = document.querySelector("[data-slide-kicker]");
const slidePoints = document.querySelector("[data-slide-points]");
let proposalsApplied = false;

const originalSlide = {
    title: "AI demos",
    kicker: "Run the prompt and talk through the answer.",
    points: ["Show the prompt", "Read the result"]
};

const renderSlide = (preview = false) => {
    const selected = new Set(
        proposalInputs.filter((input) => input.checked).map((input) => input.value)
    );
    const nextSlide = {
        title: originalSlide.title,
        kicker: originalSlide.kicker,
        points: [...originalSlide.points]
    };

    if (preview && selected.has("title")) {
        nextSlide.title = "Make the workflow visible";
    }
    if (preview && selected.has("structure")) {
        nextSlide.kicker = "A live demo in three visible moves.";
        nextSlide.points = [
            "Frame the prompt and its constraints",
            "Stream the answer beside the source",
            "Keep the result in the deck"
        ];
    }
    if (preview && selected.has("proof")) {
        nextSlide.points.push("End on the verification command");
    }

    if (slideTitle) slideTitle.textContent = nextSlide.title;
    if (slideKicker) slideKicker.textContent = nextSlide.kicker;
    if (slidePoints) {
        const items = nextSlide.points.map((point) => {
            const item = document.createElement("li");
            item.textContent = point;
            return item;
        });
        slidePoints.replaceChildren(...items);
    }

    if (assistantSlide) assistantSlide.dataset.preview = String(preview);
    if (slideState) slideState.textContent = preview ? "Illustrative result" : "Current slide";
    if (applyProposalsButton) {
        applyProposalsButton.textContent = preview ? "Reset preview" : "Preview changes";
    }
};

const updateSelectionCount = () => {
    const count = proposalInputs.filter((input) => input.checked).length;
    if (selectionCount) selectionCount.textContent = `${count} selected`;
    if (applyProposalsButton) applyProposalsButton.disabled = count === 0;
};

proposalInputs.forEach((input) => {
    input.addEventListener("change", () => {
        if (proposalsApplied) {
            proposalsApplied = false;
            renderSlide(false);
        }
        updateSelectionCount();
    });
});

applyProposalsButton?.addEventListener("click", () => {
    proposalsApplied = !proposalsApplied;
    renderSlide(proposalsApplied);
});

updateSelectionCount();

const themeNames = {
    studio: "Studio",
    midnight: "Midnight",
    chalk: "Chalk",
    solar: "Solar",
    atelier: "Atelier"
};

const themeStudio = document.querySelector("[data-theme-preview]");
const themeLabel = document.querySelector("[data-theme-label]");
const themeButtons = [...document.querySelectorAll("[data-theme]")];

const selectTheme = (button) => {
    const theme = button.dataset.theme;
    if (!theme || !themeStudio) return;

    themeStudio.dataset.themePreview = theme;
    if (themeLabel) themeLabel.textContent = themeNames[theme] || theme;
    themeButtons.forEach((candidate) => {
        candidate.setAttribute("aria-pressed", String(candidate === button));
    });
};

themeButtons.forEach((button, index) => {
    button.addEventListener("click", () => selectTheme(button));
    button.addEventListener("keydown", (event) => {
        if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") return;

        event.preventDefault();
        const direction = event.key === "ArrowRight" ? 1 : -1;
        const nextIndex = (index + direction + themeButtons.length) % themeButtons.length;
        themeButtons[nextIndex].focus();
        selectTheme(themeButtons[nextIndex]);
    });
});

const copyButton = document.querySelector("[data-copy-format]");
const formatSource = document.querySelector("[data-format-source]");
let copyResetTimer;

const legacyCopy = (text) => {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.append(textarea);
    textarea.select();
    const copied = document.execCommand("copy");
    textarea.remove();
    return copied;
};

copyButton?.addEventListener("click", async () => {
    if (!formatSource) return;

    const text = formatSource.textContent || "";
    let copied = false;

    try {
        await navigator.clipboard.writeText(text);
        copied = true;
    } catch {
        copied = legacyCopy(text);
    }

    window.clearTimeout(copyResetTimer);
    copyButton.textContent = copied ? "Copied" : "Select and copy";
    copyResetTimer = window.setTimeout(() => {
        copyButton.textContent = "Copy example";
    }, 1800);
});

const revealElements = [...document.querySelectorAll("[data-reveal]")];

if (prefersReducedMotion.matches || !("IntersectionObserver" in window)) {
    revealElements.forEach((element) => element.classList.add("is-visible"));
} else {
    const revealObserver = new IntersectionObserver(
        (entries, observer) => {
            entries.forEach((entry) => {
                if (!entry.isIntersecting) return;
                entry.target.classList.add("is-visible");
                observer.unobserve(entry.target);
            });
        },
        { rootMargin: "0px 0px -9%", threshold: 0.08 }
    );
    revealElements.forEach((element) => revealObserver.observe(element));
}

const navigationLinks = [
    ...document.querySelectorAll('.desktop-nav a[href^="#"], .mobile-menu a[href^="#"]')
];
const navigationSections = navigationLinks
    .map((link) => document.querySelector(link.getAttribute("href")))
    .filter((section, index, sections) => section && sections.indexOf(section) === index);

if ("IntersectionObserver" in window) {
    const navigationObserver = new IntersectionObserver(
        (entries) => {
            const visible = entries
                .filter((entry) => entry.isIntersecting)
                .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
            if (!visible) return;

            navigationLinks.forEach((link) => {
                const isCurrent = link.getAttribute("href") === `#${visible.target.id}`;
                if (isCurrent) {
                    link.setAttribute("aria-current", "location");
                } else {
                    link.removeAttribute("aria-current");
                }
            });
        },
        { rootMargin: "-30% 0px -58%", threshold: [0, 0.2, 0.6] }
    );
    navigationSections.forEach((section) => navigationObserver.observe(section));
}

const tiltStage = document.querySelector("[data-tilt]");
const supportsFinePointer = window.matchMedia("(hover: hover) and (pointer: fine)");

if (tiltStage && supportsFinePointer.matches && !prefersReducedMotion.matches) {
    let tiltFrame;
    let nextTilt;

    tiltStage.addEventListener("pointermove", (event) => {
        const bounds = tiltStage.getBoundingClientRect();
        const x = (event.clientX - bounds.left) / bounds.width - 0.5;
        const y = (event.clientY - bounds.top) / bounds.height - 0.5;
        nextTilt = { x, y };
        tiltStage.classList.add("is-tilting");

        if (tiltFrame) return;
        tiltFrame = window.requestAnimationFrame(() => {
            tiltStage.style.setProperty("--tilt-x", `${nextTilt.x * 4.5}deg`);
            tiltStage.style.setProperty("--tilt-y", `${nextTilt.y * -3.5}deg`);
            tiltFrame = undefined;
        });
    });

    tiltStage.addEventListener("pointerleave", () => {
        if (tiltFrame) window.cancelAnimationFrame(tiltFrame);
        tiltFrame = undefined;
        tiltStage.style.setProperty("--tilt-x", "0deg");
        tiltStage.style.setProperty("--tilt-y", "0deg");
        tiltStage.classList.remove("is-tilting");
    });
}
