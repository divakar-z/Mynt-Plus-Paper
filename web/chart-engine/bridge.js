'use strict';

// ---------------------------------------------------------------------------
// Bridge — typed two-way messaging between the chart iframe and Flutter host.
//
// Outbound: always JSON-stringified (Dart Map ↔ JS Object round-trip is
// unreliable through dart:html postMessage; we proved this in Phase 1).
//
// Two flavours:
//   1) `post(type, value)` — fire-and-forget. Flutter handles or ignores.
//   2) `request(type, value)` → Promise<reply>. Flutter must reply with the
//      same `replyTo` correlation id we set on outbound. Times out after 5s.
//
// Inbound: a handler registry. Each `type` maps to one handler. Replies
// (messages with a `replyId` field) bypass the registry and fulfil any
// pending request promise.
// ---------------------------------------------------------------------------

window.bridge = (function () {
  const handlers = new Map();              // type -> handler(value)
  const pending = new Map();               // replyId -> { resolve, reject, timer }
  let nextReplyId = 1;

  function _newReplyId() {
    return 'r' + (nextReplyId++) + ':' + Date.now().toString(36);
  }

  function post(type, value) {
    try { parent.postMessage(JSON.stringify({ type, value }), '*'); } catch (_) {}
  }

  // Send a request and await Flutter's reply. Flutter is expected to post
  // back `{ type: 'reply', value: { replyId, payload } }` (or `{ error }`).
  function request(type, value, { timeoutMs = 5000 } = {}) {
    return new Promise((resolve, reject) => {
      const replyTo = _newReplyId();
      const timer = setTimeout(() => {
        pending.delete(replyTo);
        reject(new Error('bridge.request timed out: ' + type));
      }, timeoutMs);
      pending.set(replyTo, { resolve, reject, timer });
      try {
        parent.postMessage(
            JSON.stringify({ type, value, replyTo }), '*');
      } catch (e) {
        clearTimeout(timer);
        pending.delete(replyTo);
        reject(e);
      }
    });
  }

  function on(type, handler) {
    handlers.set(type, handler);
  }

  function _handleIncoming(d) {
    // Reply path — fulfil the pending request promise.
    if (d.type === 'reply' && d.value && typeof d.value.replyId === 'string') {
      const slot = pending.get(d.value.replyId);
      if (!slot) return;
      pending.delete(d.value.replyId);
      clearTimeout(slot.timer);
      if (d.value.error) slot.reject(new Error(d.value.error));
      else slot.resolve(d.value.payload);
      return;
    }
    // Registered handler.
    const h = handlers.get(d.type);
    if (h) h(d.value);
  }

  window.addEventListener('message', (e) => {
    let d = e.data;
    if (typeof d === 'string') {
      try { d = JSON.parse(d); } catch (_) { return; }
    }
    if (!d || typeof d !== 'object' || typeof d.type !== 'string') return;
    _handleIncoming(d);
  });

  return { post, request, on };
})();
