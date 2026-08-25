/**
 * Privacy-Preserving WebRTC Mesh Signaling for ECHO//LINE (أصداء)
 * Handles SDP Offer/Answer routing, ICE Candidate relay, and parental voice disable controls.
 */

class WebRTCSignalingManager {
  constructor(roomManager) {
    this.roomManager = roomManager;
    this.voiceMutedUsers = new Set(); // userIds with voice disabled/parental lock
  }

  setParentalVoiceLock(userId, isLocked) {
    if (isLocked) {
      this.voiceMutedUsers.add(userId);
    } else {
      this.voiceMutedUsers.delete(userId);
    }
  }

  handleSignalingMessage(socket, senderId, roomCode, payload) {
    if (this.voiceMutedUsers.has(senderId)) {
      return { success: false, error: 'Voice communication disabled by parental/safety controls' };
    }

    const room = this.roomManager.getRoom(roomCode);
    if (!room) return { success: false, error: 'Room not found' };

    const { targetUserId, signalType, sdp, candidate } = payload;
    const targetPlayer = room.players.get(targetUserId);

    if (targetPlayer && targetPlayer.socket && targetPlayer.socket.readyState === 1) {
      targetPlayer.socket.send(JSON.stringify({
        type: 'WEBRTC_SIGNAL',
        payload: {
          fromUserId: senderId,
          signalType,
          sdp,
          candidate
        },
        timestamp: Date.now()
      }));
      return { success: true };
    }

    return { success: false, error: 'Target peer unavailable' };
  }
}

module.exports = {
  WebRTCSignalingManager
};
