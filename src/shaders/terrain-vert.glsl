#version 300 es


uniform mat4 u_Model;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane

in vec4 vs_Pos;
in vec4 vs_Nor;
in vec4 vs_Col;

out vec3 fs_Pos;
out vec4 fs_Nor;
out vec4 fs_Col;

out float fs_Sine;
out float fs_Height;

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

float random1( vec3 p , vec3 seed) {
  return fract(sin(dot(p + seed, vec3(987.654, 123.456, 531.975))) * 85734.3545);
}

vec2 random2( vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(311.7, 127.1)), dot(p + seed, vec2(269.5, 183.3)))) * 85734.3545);
}

float randv(vec2 n) {
  float v = (fract(cos(dot(n, vec2(12.9898, 4.1414))) * 43758.5453));
  return v;
}

float interpNoise2D(vec2 p) {
    float intX = floor(p.x);
    float intY = floor(p.y);
    float fractX = fract(p.x);
    float fractY = fract(p.y);

    float v1 = randv(vec2(intX,intY));
    float v2 = randv(vec2(intX + 1.0,intY));
    float v3 = randv(vec2(intX,intY + 1.0));
    float v4 = randv(vec2(intX + 1.0,intY + 1.0));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);

    return mix(i1, i2, fractY);
}

// Normal fbm
float fbm(vec2 p, float persistence, float octaves) {
    p /= 10.0f; // higher divisor = less variability of land; lower = really random/jumpy
    float total = 0.0;

    for (float i = 0.0; i < octaves; i++) {
        float freq = pow(2.0, i);
        float amp = pow(persistence, i);
        total += interpNoise2D(vec2(p.x * freq, p.y * freq)) * amp;
    }
    return total;
}

void main() {
  fs_Pos = vs_Pos.xyz;
  fs_Sine = (sin((vs_Pos.x + u_PlanePos.x) * 3.14159 * 0.1) + cos((vs_Pos.z + u_PlanePos.y) * 3.14159 * 0.1));
  vec4 modelposition = vec4(vs_Pos.x, fs_Sine * 2.0, vs_Pos.z, 1.0);

  // Calculate height based on x, z coords using fbm

  // Painted mountains
  // float pert = fbm(vec2((vs_Pos.x + u_PlanePos[0]) / 2.0, (vs_Pos.z + u_PlanePos[1]) / 2.2), 1.0 / 2.0, 8.0);
  // float height = pow(pert * 6.0, 1.50);
  
  // Island
  float pert = fbm(vec2((vs_Pos.x + u_PlanePos[0]) / 5.0, (vs_Pos.z + u_PlanePos[1]) / 5.2), 1.0 / 2.0, 12.0);
  float height = pow(pert * 6.0, 1.70);


  // Saw-tooth wave


  fs_Height = height;
  modelposition[1] = height;

  modelposition = u_Model * modelposition;
  gl_Position = u_ViewProj * modelposition;
}
