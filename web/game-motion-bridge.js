(() => {
  window.motionMirrorExternalUI = true;
  window.motionMirrorQueue = [];
  window.motionMirrorStatus = "Enter phone code";
  window.motionMirrorTakePacket = () => {
    const packet = window.motionMirrorQueue.shift();
    return packet ? JSON.stringify(packet) : "";
  };

  const panel = document.createElement("section");
  panel.id = "motion-pairing";
  panel.innerHTML = `
    <strong>PHONE BODY TRACKING</strong>
    <input aria-label="Phone pairing code" maxlength="6" placeholder="6-character phone code">
    <button type="button">Connect phone</button>
    <small>Open <b>/phone/</b> on your phone</small>`;
  Object.assign(panel.style, {
    position: "fixed", left: "18px", top: "18px", zIndex: "1000", width: "260px",
    display: "none", gap: "8px", padding: "12px", borderRadius: "10px",
    color: "#eef5ff", background: "rgba(10,14,23,.92)", font: "14px system-ui,sans-serif"
  });
  const input = panel.querySelector("input"), button = panel.querySelector("button"), note = panel.querySelector("small");
  for (const control of [input, button]) Object.assign(control.style, {padding:"10px",borderRadius:"6px",border:"1px solid #394760",font:"inherit"});
  Object.assign(button.style, {background:"#72f2c6",color:"#07110e",fontWeight:"800",cursor:"pointer"});
  document.body.appendChild(panel);
  let pauseMenuOpen = false;
  window.motionMirrorSetPauseMenu = open => {
    pauseMenuOpen = Boolean(open);
    panel.style.display = pauseMenuOpen ? "grid" : "none";
  };

  const setStatus = text => { window.motionMirrorStatus = text; note.textContent = text; };
  const loadPeer = callback => {
    if (window.Peer) return callback();
    const script = document.createElement("script");
    script.src = "https://cdn.jsdelivr.net/npm/peerjs@1.5.5/dist/peerjs.min.js";
    script.onload = callback;
    script.onerror = () => setStatus("Connection service unavailable");
    document.head.appendChild(script);
  };
  const connect = () => {
    const code = input.value.trim().replace(/[^a-z0-9]/gi, "").slice(0, 6).toLowerCase();
    if (code.length !== 6) return setStatus("Enter the 6-character code");
    setStatus("Connecting...");
    loadPeer(() => {
      window.motionMirrorPeer?.destroy();
      const peer = new window.Peer();
      window.motionMirrorPeer = peer;
      peer.on("open", () => {
        const connection = peer.connect(`warformed-motion-${code}`, {reliable:false});
        connection.on("open", () => setStatus("Phone connected"));
        connection.on("data", packet => {
          if (window.motionMirrorQueue.length > 2) window.motionMirrorQueue.shift();
          window.motionMirrorQueue.push(packet);
        });
        connection.on("close", () => { panel.style.display = pauseMenuOpen ? "grid" : "none"; setStatus("Phone disconnected"); });
        connection.on("error", () => setStatus("Connection failed"));
      });
      peer.on("error", () => setStatus("Phone not found"));
    });
  };
  button.addEventListener("click", connect);
  input.addEventListener("keydown", event => { if (event.key === "Enter") connect(); });
})();
