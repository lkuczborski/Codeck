const themeNames = {
  studio: "Studio",
  midnight: "Midnight",
  chalk: "Chalk",
  solar: "Solar",
  atelier: "Atelier"
};

const playground = document.querySelector("[data-theme-preview]");
const themeLabel = document.querySelector("[data-theme-label]");

document.querySelectorAll("[data-theme]").forEach((button) => {
  button.addEventListener("click", () => {
    const theme = button.dataset.theme;
    if (!theme || !playground || !themeLabel) return;

    playground.dataset.themePreview = theme;
    themeLabel.textContent = themeNames[theme] || theme;

    document.querySelectorAll("[data-theme]").forEach((candidate) => {
      candidate.setAttribute("aria-pressed", String(candidate === button));
    });
  });
});

const runButton = document.querySelector("[data-run-demo]");
const demoStatus = document.querySelector("[data-demo-status]");
const demoOutput = document.querySelector("[data-demo-output]");

const streamedLines = [
  "<strong>Three practical ways:</strong>",
  "1. Define observable behavior in terms of inputs and outputs.",
  "2. Name the test or verification command before asking for the change.",
  "3. Keep one acceptance check on the slide so the demo can be repeated."
];

runButton?.addEventListener("click", () => {
  if (!demoStatus || !demoOutput || runButton.disabled) return;

  runButton.disabled = true;
  demoStatus.textContent = "running";
  demoOutput.innerHTML = "";

  streamedLines.forEach((line, index) => {
    window.setTimeout(() => {
      const block = document.createElement("p");
      block.innerHTML = line;
      demoOutput.append(block);

      if (index === streamedLines.length - 1) {
        demoStatus.textContent = "completed";
        runButton.disabled = false;
      }
    }, 360 * (index + 1));
  });
});

const header = document.querySelector("[data-elevates]");

const updateHeader = () => {
  if (!header) return;
  header.toggleAttribute("data-scrolled", window.scrollY > 16);
};

updateHeader();
window.addEventListener("scroll", updateHeader, { passive: true });
