#version 450

in vec3 pos;
in vec2 uv;
out vec2 vUV;

void main() {
    vUV = uv;
	gl_Position = vec4(pos, 1.0);
}
