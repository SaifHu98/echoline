const { WebSocket } = require('ws');

class TestClient {
  constructor(ws, id) {
    this.ws = ws;
    this.id = id;
    this.inbox = [];
    this.listeners = [];

    this.ws.on('message', (data) => {
      try {
        const msg = JSON.parse(data.toString());
        // Check if there is a pending listener for this type
        const idx = this.listeners.findIndex(l => l.type === msg.type);
        if (idx !== -1) {
          const listener = this.listeners.splice(idx, 1)[0];
          clearTimeout(listener.timer);
          listener.resolve(msg);
        } else {
          this.inbox.push(msg);
        }
      } catch (e) {}
    });
  }

  static connect(port, id) {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(`ws://localhost:${port}`);
      ws.on('open', () => resolve(new TestClient(ws, id)));
      ws.on('error', reject);
    });
  }

  send(msg) {
    this.ws.send(JSON.stringify(msg));
  }

  waitFor(expectedType, timeoutMs = 3000) {
    // Check inbox first
    const inboxIdx = this.inbox.findIndex(m => m.type === expectedType);
    if (inboxIdx !== -1) {
      const msg = this.inbox.splice(inboxIdx, 1)[0];
      return Promise.resolve(msg);
    }

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const idx = this.listeners.findIndex(l => l.resolve === resolve);
        if (idx !== -1) this.listeners.splice(idx, 1);
        reject(new Error(`[${this.id}] Timeout waiting for message: ${expectedType}`));
      }, timeoutMs);

      this.listeners.push({ type: expectedType, resolve, timer });
    });
  }

  close() {
    if (this.ws.readyState === 1) {
      this.ws.close();
    }
  }
}

module.exports = {
  TestClient
};
