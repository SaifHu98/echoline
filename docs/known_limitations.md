# Known Limitations — ECHO//LINE (أصداء) Vertical Slice

This document records deliberate scoping boundaries, known technical limitations, and architectural deferrals for the first vertical slice in accordance with Section 24 of `promat.md`.

---

## 1. Multiplayer & Networking Boundaries
* **Voice Chat**: Real-time voice transport and neural voice translation are deferred to Closed Beta to ensure privacy and low latency on mobile networks. The vertical slice is 100% playable via semantic quick messages and smart pings.
* **Matchmaking Pool**: Private 4-character room codes are implemented. Global automated queue matchmaking is architected in `docs/architecture.md` and scheduled for Phase 5.
* **Player Scale**: The vertical slice is tuned for 2–4 players in Cooperative Timeline Rescue mode (Mode A). 5–8 player Temporal Traitor mode (Mode B) and 2-player emotional Story mode (Mode D) are scheduled for Closed Alpha.

---

## 2. Platform & Asset Limitations
* **Renderer**: Stylized low-poly geometric environment meshes with dynamic lighting are used for the Clocktower District slice. Production high-density PBR textures and lightmaps are scheduled for production release.
* **Fonts**: Default engine fallback with Noto Sans Unicode coverage is configured for development testing. Custom Arabic calligraphy typography branding is post-MVP.

---

## 3. Gameplay & Simulation Scope
* **Scenario Count**: The Clocktower District vertical slice is fully implemented with 10 echo rules, 3 interacting catastrophe systems, and multiple victory outcomes. Additional district scenarios (e.g. Subterranean Vaults, High-Frequency Spire) will use the same declarative scenario schema pipeline in future milestones.
