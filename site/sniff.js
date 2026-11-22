// A mecânica do jogo na página: farejar revela o que está escondido.
// Três pistas abrem a Lixeira. Nada é guardado nem enviado.
(() => {
  "use strict";

  const body = document.body;
  const buttons = document.querySelectorAll("button[data-sniff]");
  const clues = document.querySelectorAll("button[data-clue]");
  const pips = document.querySelectorAll(".pips i");
  const toast = document.querySelector(".toast");
  const trash = document.getElementById("trash");

  let latched = false; // pelo botão
  let held = false;    // pelo Shift
  let found = 0;
  let timer = 0;

  for (const element of document.querySelectorAll(".needs-js")) element.hidden = false;

  function say(text) {
    toast.textContent = text;
    clearTimeout(timer);
    timer = setTimeout(() => { toast.textContent = ""; }, 3200);
  }

  function update() {
    const on = latched || held;
    body.classList.toggle("sniffing", on);
    for (const button of buttons) button.setAttribute("aria-pressed", String(on));
  }

  for (const button of buttons) {
    button.addEventListener("click", () => {
      latched = !latched;
      update();
      if (latched && found < clues.length) say("Sniffing. Buried clues are showing.");
    });
  }

  addEventListener("keydown", (event) => {
    if (event.key !== "Shift" || event.repeat) return;
    held = true;
    update();
  });
  addEventListener("keyup", (event) => {
    // Shift+Tab até uma pista não pode apagar a pista que está com o foco
    if (event.key !== "Shift") return;
    held = false;
    if (document.activeElement && document.activeElement.matches("[data-clue]")) latched = true;
    update();
  });
  addEventListener("blur", () => {
    held = false;
    update();
  });

  for (const clue of clues) {
    clue.addEventListener("click", () => {
      if (clue.classList.contains("found")) return;
      clue.classList.add("found");
      pips[found].classList.add("on");
      found += 1;
      if (found < clues.length) {
        say(`Clue ${found} of ${clues.length} unearthed.`);
        document.querySelector(".sniff").focus({ preventScroll: true });
        return;
      }
      say("All clues found. The Trash is open.");
      trash.hidden = false;
      trash.focus({ preventScroll: true });
      const calm = matchMedia("(prefers-reduced-motion: reduce)").matches;
      trash.scrollIntoView({ behavior: calm ? "auto" : "smooth", block: "center" });
    });
  }
})();
