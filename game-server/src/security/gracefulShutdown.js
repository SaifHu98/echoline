'use strict';

/**
 * GracefulShutdown — clean process termination
 * ==============================================
 * - Stop accepting new connections
 * - Drain active rooms (notify clients)
 * - Allow in-flight requests up to N seconds
 * - Force-kill after deadline
 */

class GracefulShutdown {
  constructor({ logger, server, roomManager, io, drainTimeoutMs = 10000 }) {
    this.logger = logger;
    this.server = server;
    this.roomManager = roomManager;
    this.io = io;
    this.drainTimeoutMs = drainTimeoutMs;
    this.shuttingDown = false;
    this._hooksInstalled = false;
  }

  install() {
    if (this._hooksInstalled) return;
    this._hooksInstalled = true;

    process.on('SIGTERM', () => this._begin('SIGTERM'));
    process.on('SIGINT',  () => this._begin('SIGINT'));

    process.on('uncaughtException', (err) => {
      this.logger.error('uncaught_exception', { error: err.message, stack: err.stack });
      // Don't auto-shutdown on uncaught exception; log and continue
    });

    process.on('unhandledRejection', (reason) => {
      this.logger.error('unhandled_rejection', {
        reason: reason && reason.message ? reason.message : String(reason),
      });
    });
  }

  async _begin(signal) {
    if (this.shuttingDown) return;
    this.shuttingDown = true;
    this.logger.info('shutdown.begin', { signal });

    // 1) Notify all connected clients
    try {
      if (this.io) {
        this.io.emit('server:closing', { reason: 'maintenance', grace_seconds: this.drainTimeoutMs / 1000 });
      }
    } catch (e) {
      this.logger.warn('shutdown.notify_failed', { error: e.message });
    }

    // 2) Stop accepting new connections
    if (this.server) {
      this.server.close((err) => {
        if (err) {
          this.logger.error('shutdown.server_close_error', { error: err.message });
        }
      });
    }

    // 3) Stop new room creation
    if (this.roomManager && typeof this.roomManager.stopAccepting === 'function') {
      this.roomManager.stopAccepting();
    }

    // 4) Force-kill after timeout
    const killTimer = setTimeout(() => {
      this.logger.warn('shutdown.force_kill', { waited_ms: this.drainTimeoutMs });
      process.exit(1);
    }, this.drainTimeoutMs);
    if (killTimer.unref) killTimer.unref();

    // 5) Wait for active rooms to drain (best-effort)
    try {
      if (this.roomManager && typeof this.roomManager.waitForDrain === 'function') {
        await this.roomManager.waitForDrain(this.drainTimeoutMs - 1000);
      }
    } catch (e) {
      this.logger.warn('shutdown.drain_timeout', { error: e.message });
    }

    // 6) Final flush
    clearTimeout(killTimer);
    this.logger.info('shutdown.complete');
    process.exit(0);
  }

  isShuttingDown() {
    return this.shuttingDown;
  }
}

module.exports = { GracefulShutdown };