# Mobile Performance Targets & Optimization — ECHO//LINE (أصداء)

## 1. Frame Rate & Memory Targets
* **Target FPS**: Stable 60 FPS on mid-range mobile devices (Snapdragon 7 series / Apple A13+); 30 FPS fallback on low-end.
* **Memory Budget**: < 250 MB RAM client footprint during match runtime.
* **Package Size**: < 80 MB initial download.

## 2. Rendering Optimization Rules
* **Unified Mesh Reuse**: Past, Present, and Future share common environment static meshes. Timelines apply timeline-specific state materials and prop layers rather than loading 3 distinct separate scenes.
* **Low Draw Calls**: Dynamic batching and texture atlasing for UI and environment elements.
* **Reduced Motion & Shaders**: Ripple distortion falls back to alpha-blended geometric meshes on mobile profiles.
