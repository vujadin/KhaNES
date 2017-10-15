#version 450

in vec2 vUV;
uniform vec2 res;
uniform sampler2D nesFrame;
out vec4 fragColor;

// based on https://www.shadertoy.com/view/Ms23DR
vec2 curve(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	uv *= 1.1;	
	uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
	uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
	uv  = (uv / 2.0) + 0.5;
	uv =  uv *0.92 + 0.04;
	return uv;
}

void main() {
    vec2 q = vUV.xy / res.xy;
    vec2 uv = curve(vUV);
    vec3 oricol = texture(nesFrame, vec2(vUV.x,vUV.y)).xyz;
    vec3 col;

    col.r = texture(nesFrame,vec2(uv.x+0.001,uv.y+0.001)).x+0.05;
    col.g = texture(nesFrame,vec2(uv.x+0.000,uv.y-0.002)).y+0.05;
    col.b = texture(nesFrame,vec2(uv.x-0.002,uv.y+0.000)).z+0.05;

    col = clamp(col*0.6+0.4*col*col*1.0,0.0,1.0);

    float vig = (0.0 + 1.0*16.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y));
	col *= vec3(pow(vig,0.3));

    col *= vec3(0.95,1.05,0.95);
	col *= 2.1;

	float scans = clamp( 0.35+0.35*sin(3.5+uv.y*res.y*1.4), 0.0, 1.0);
	
	float s = pow(scans,1.1);
	col = col*vec3( 0.4+0.7*s) ;

	if (uv.x < 0.0 || uv.x > 1.0)
		col *= 0.0;
	if (uv.y < 0.0 || uv.y > 1.0)
		col *= 0.0;
	
	col*=1.0-0.65*vec3(clamp((mod(vUV.x, 2.0)-1.0)*2.0,0.0,1.0));

    fragColor = vec4(col,1.0);
}
