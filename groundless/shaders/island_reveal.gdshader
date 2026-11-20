// Island reveal: at reveal 0 an island is a flat dark silhouette against the sky;
// at 1 it shows its full colour. Each island drives `reveal` from its distance to the raft.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.5, 0.5, 0.5);
uniform vec3 silhouette_color : source_color = vec3(0.1, 0.08, 0.15);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_strength = 0.0;
instance uniform float reveal = 1.0;

void fragment() {
	ALBEDO = mix(silhouette_color, base_color, reveal);
	ROUGHNESS = 0.95;
	SPECULAR = 0.25 * reveal;
	EMISSION = emission_color * emission_strength * mix(0.3, 1.0, reveal);
}
