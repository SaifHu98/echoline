class_name DeviceProfiles
extends RefCounted

# Device Quality Profiles & Scalability Manager for Mid-Range & Flagship Mobile

enum QualityTier {
	LOW_POWER_30FPS,
	BALANCED_MIDRANGE,
	HIGH_PERFORMANCE_60FPS
}

static func apply_quality_profile(tree: SceneTree, tier: QualityTier) -> void:
	var root = tree.root
	match tier:
		QualityTier.LOW_POWER_30FPS:
			Engine.max_fps = 30
			RenderingServer.viewport_set_msaa_2d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED)
			RenderingServer.viewport_set_msaa_3d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED)
			RenderingServer.viewport_set_screen_space_aa(root.get_viewport_rid(), RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		
		QualityTier.BALANCED_MIDRANGE:
			Engine.max_fps = 60
			RenderingServer.viewport_set_msaa_2d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X)
			RenderingServer.viewport_set_msaa_3d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X)
			RenderingServer.viewport_set_screen_space_aa(root.get_viewport_rid(), RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.directional_shadow_atlas_set_size(2048, true)

		QualityTier.HIGH_PERFORMANCE_60FPS:
			Engine.max_fps = 60
			RenderingServer.viewport_set_msaa_2d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)
			RenderingServer.viewport_set_msaa_3d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)
			RenderingServer.viewport_set_screen_space_aa(root.get_viewport_rid(), RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
