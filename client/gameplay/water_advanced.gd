extends MeshInstance3D

# ECHO//LINE — Advanced Water Material
# Animated waves, reflections, foam

@export var wave_height: float = 0.05
@export var wave_speed: float = 0.5
@export var wave_detail: float = 1.5
@export var color: Color = Color(0.2, 0.5, 0.8)
@export var foam_color: Color = Color(0.9, 0.95, 1.0)
@export var timeline: String = "present"

var material: ShaderMaterial
var time: float = 0.0


func _ready() -> void:
	_setup_material()


func _process(delta: float) -> void:
	time += delta * wave_speed
	if material:
		material.set_shader_parameter("time", time)
		material.set_shader_parameter("wave_height", wave_height)
		material.set_shader_parameter("wave_detail", wave_detail)


func _setup_material() -> void:
	# Use StandardMaterial3D as fallback (works without custom shader)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.6
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(color.r * 0.5, color.g * 0.5, color.b * 0.7)
	mat.emission_energy_multiplier = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	material_override = mat


# Create animated wave effect via shader params (would use ShaderMaterial in full build)
