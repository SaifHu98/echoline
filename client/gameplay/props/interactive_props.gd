extends InteractiveProp

# ECHO//LINE — Canal Debris (PAST Timeline)
# Stub — full interactive props file has been split into separate files
# for each prop type. See CanalDebris, CourtyardSoil, etc. in this folder.
# This file remains as a placeholder so the addon folder structure is intact.

func _ready() -> void:
	prop_id = "canal_debris"
	display_name = "Canal Debris"
	action_name = "Clear"
	requires_timeline = "past"
	super._ready()
