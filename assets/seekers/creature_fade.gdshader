shader_type spatial;
// 아래로 갈수록 투명해지는 천 (유령 옷자락·마녀 안개)
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
#define FADE
#include "res://assets/seekers/creature.gdshaderinc"
