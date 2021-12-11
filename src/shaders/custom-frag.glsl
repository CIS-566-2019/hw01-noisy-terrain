#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.

uniform highp int u_Time;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;


out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.
vec3 random3( vec3 p ) {
    return fract(sin(vec3(dot(p,vec3(127.1, 311.7, 456.9)),
                          dot(p,vec3(269.5, 183.3, 236.6)),
                          dot(p, vec3(420.6, 631.2, 235.1))
                    )) * 438648.5453);
}
float surflet(vec3 p, vec3 gridPoint) {
    // Compute the distance between p and the grid point along each axis, and warp it with a
    // quintic function so we can smooth our cells
    vec3 t2 = abs(p - gridPoint);
    vec3 pow5 = vec3(pow(t2.x, 5.0), pow(t2.y, 5.0), pow(t2.z, 5.0));
    vec3 pow4 = vec3(pow(t2.x, 4.0), pow(t2.y, 4.0), pow(t2.z, 4.0));
    vec3 pow3 = vec3(pow(t2.x, 3.0), pow(t2.y, 3.0), pow(t2.z, 3.0));
    vec3 t = vec3(1.f, 1.f, 1.f) - 6.f * pow5 + 15.f * pow4 - 10.f * pow3;
    // Get the random vector for the grid point (assume we wrote a function random2
    // that returns a vec2 in the range [0, 1])
    vec3 gradient1 = random3(gridPoint) * 2. - vec3(1., 1., 1.);
    vec3 gradient2 = random3(gridPoint) * 3. - vec3(1., 1., 1.);
    vec3 gradient = gradient1 + sin(float(u_Time) * 0.02) * (gradient2 - gradient1);
    // Get the vector from the grid point to P
    vec3 diff = p - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    //Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * t.x * t.y * t.z;
}

float perlinNoise3D(vec3 p) {
	float surfletSum = 0.f;
	// Iterate over the four integer corners surrounding uv
	for(int dx = 0; dx <= 1; ++dx) {
		for(int dy = 0; dy <= 1; ++dy) {
			for(int dz = 0; dz <= 1; ++dz) {
				surfletSum += surflet(p, floor(p) + vec3(dx, dy, dz));
			}
		}
	}
	return surfletSum;
}

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color;

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        // diffuseTerm = clamp(diffuseTerm, 0, 1);

        float ambientTerm = 0.2;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        // Compute final shaded color
        float n1 = perlinNoise3D(fs_Pos.xyz * 20.0);
        float n2 = perlinNoise3D(fs_Pos.xyz * 5.0);
        vec4 layer = 0.4 * vec4(n1, n1, n1, 1.0) + 0.6 * vec4(n2, n2, n2, 1.0);
        vec4 layer2 = 0.5 * diffuseColor / vec4(n1, n1, n1, 1.0) + 0.5 * diffuseColor / vec4(n2, n2, n2, 1.0);
        diffuseColor = diffuseColor + diffuseColor * layer + 0.5 * diffuseColor * layer2 * layer2 / 100.0;
        out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
}
