/**
 * Admin Dashboard REST API Server for ECHO//LINE (أصداء)
 * Powers real-time liveops event scheduling, scenario creation, shop management, and Google Play verification.
 */

const http = require('http');
const path = require('path');
const fs = require('fs');

class AdminApiServer {
  constructor(liveopsManager, shopService, billingValidator, port = 7778) {
    this.liveopsManager = liveopsManager;
    this.shopService = shopService;
    this.billingValidator = billingValidator;
    this.port = port;
    this.server = null;
  }

  start() {
    return new Promise((resolve) => {
      this.server = http.createServer((req, res) => {
        // Enable CORS
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

        if (req.method === 'OPTIONS') {
          res.writeHead(204);
          res.end();
          return;
        }

        const url = new URL(req.url, `http://${req.headers.host}`);
        const pathname = url.pathname;

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', async () => {
          let data = {};
          if (body) {
            try { data = JSON.parse(body); } catch (e) {}
          }

          // Routes
          if (pathname === '/api/admin/events' && req.method === 'GET') {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(this.liveopsManager.events));
          }
          else if (pathname === '/api/admin/events' && req.method === 'POST') {
            const created = this.liveopsManager.createEvent(data);
            res.writeHead(201, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: true, event: created }));
          }
          else if (pathname.startsWith('/api/admin/events/') && req.method === 'PUT') {
            const eventId = pathname.replace('/api/admin/events/', '');
            const updated = this.liveopsManager.updateEvent(eventId, data);
            res.writeHead(updated ? 200 : 404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: Boolean(updated), event: updated }));
          }
          else if (pathname.startsWith('/api/admin/events/') && req.method === 'DELETE') {
            const eventId = pathname.replace('/api/admin/events/', '');
            const deleted = this.liveopsManager.deleteEvent(eventId);
            res.writeHead(deleted ? 200 : 404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: deleted }));
          }
          else if (pathname === '/api/admin/shop' && req.method === 'GET') {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(this.shopService.getCatalog()));
          }
          else if (pathname === '/api/admin/shop/items' && req.method === 'POST') {
            this.shopService.addItem(data);
            res.writeHead(201, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: true, item: data }));
          }
          else if (pathname.startsWith('/api/admin/shop/items/') && req.method === 'PUT') {
            const itemId = pathname.replace('/api/admin/shop/items/', '');
            const updated = this.shopService.updateItem(itemId, data);
            res.writeHead(updated ? 200 : 404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: updated }));
          }
          else if (pathname.startsWith('/api/admin/shop/items/') && req.method === 'DELETE') {
            const itemId = pathname.replace('/api/admin/shop/items/', '');
            const deleted = this.shopService.deleteItem(itemId);
            res.writeHead(deleted ? 200 : 404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: deleted }));
          }
          else if (pathname === '/api/billing/google-play/verify' && req.method === 'POST') {
            const result = await this.billingValidator.verifyPurchase(data);
            if (result.success) {
              if (result.grant.shards) {
                this.shopService.creditPurchasedShards(data.userId || 'anon', result.grant.shards);
              }
            }
            res.writeHead(result.success ? 200 : 400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(result));
          }
          else {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Endpoint not found' }));
          }
        });
      });

      this.server.listen(this.port, () => {
        console.log(`[ECHO//LINE Admin API] Running on http://localhost:${this.port}`);
        resolve(this);
      });
    });
  }

  stop() {
    if (this.server) this.server.close();
  }
}

module.exports = {
  AdminApiServer
};
