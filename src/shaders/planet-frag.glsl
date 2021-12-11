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

uniform highp int u_Mode;
uniform highp int u_Ambient;
uniform highp int u_Deform;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

float bias(float b, float t) {
    return (pow(t, log(b)) / log(0.5));
}

float gain(float g, float t) {
    if (t < 0.5f) {
        return (bias(1.0 - g, 2.0 * t) / 2.0);
    }
    else {
        return (1.0 - bias(1.0 - g, 2.0 - 2.0 * t) / 2.0);
    }
}

float rand3D(vec3 p) {
    return fract(sin(dot(p, vec3(dot(p,vec3(127.1, 311.7, 456.9)),
                          dot(p,vec3(269.5, 183.3, 236.6)),
                          dot(p, vec3(420.6, 631.2, 235.1))
                    ))) * 438648.5453);
}

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
    vec3 gradient = gradient1;
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

float interpNoise3D(float x, float y, float z) {
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);
    int intZ = int(floor(z));
    float fractZ = fract(z);

    float v1 = rand3D(vec3(intX, intY, intZ));
    float v2 = rand3D(vec3(intX + 1, intY, intZ));
    float v3 = rand3D(vec3(intX, intY + 1, intZ));
    float v4 = rand3D(vec3(intX + 1, intY + 1, intZ));

    float v5 = rand3D(vec3(intX, intY, intZ + 1));
    float v6 = rand3D(vec3(intX + 1, intY, intZ + 1));
    float v7 = rand3D(vec3(intX, intY + 1, intZ + 1));
    float v8 = rand3D(vec3(intX + 1, intY + 1, intZ + 1));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);

    float i3 = mix(v5, v6, fractX);
    float i4 = mix(v7, v8, fractX);

    float i5 = mix(i1, i2, fractY);
    float i6 = mix(i3, i4, fractY);

    float i7 = mix(i5, i6, fractZ);

    return i7;
}

float fbm(float x, float y, float z) {
    float total = 0.0;
    float persistence = 0.5;
    int octaves = 8;

    for(int i = 1; i <= octaves; i++) {
        float freq = pow(2.0, float(i));
        float amp = pow(persistence, float(i));

        total += interpNoise3D(x * freq,
                               y * freq,
                               z * freq) * amp;
    }
    return total;
}

float triangle_wave(float x, float freq, float amp) {
    float a = abs(x * freq);
    float r = a - amp * floor(a/amp);
    return (r - (0.5 * amp));
}

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color;

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);

        float ambientTerm = float(u_Ambient) / 10.0;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
        
                                                            //lit by our point light are not completely black.
        //initial colors
        vec3 snow = vec3(0.78);
        vec3 alpine = vec3(0.64, 0.701, 0.57);
        vec3 ocean = vec3(0.4, 0.7, 1.0);
        vec3 water = vec3(0.2, 1.0, 1.0);
        vec3 sand = vec3(0.96, 0.93, 0.78);


        //forest color
        float p1 = perlinNoise3D(fs_Pos.xyz * 45.0);
        float p2 = perlinNoise3D(fs_Pos.xyz * 55.0);
        float p3 = perlinNoise3D(fs_Pos.xyz * 25.0);
        vec3 layer1 = vec3(p1 * vec3(0.49, 0.90, 0.38));
        vec3 layer2 = vec3(p2 * vec3(0.56, 0.58, 0.19));
        vec3 layer3 = vec3(p3 * alpine.rgb);
        vec3 forest = diffuseColor.rgb * (diffuseColor.rgb + 0.5 * layer1 + 0.3 * layer2 + 0.2 * layer3);
        
        //ocean color
        vec3 noiseInput = triangle_wave(float(u_Time), 0.025, 100.0) * 0.15 * fs_Pos.xyz;
        float f = fbm(noiseInput.x, noiseInput.y, noiseInput.z);
        float f1 = fbm(noiseInput.x + f, noiseInput.y + f, noiseInput.z + f);
        ocean = ocean + 6.0 * f1 * ocean + 6.0 * f1 * f1 * f1 * f1 * water;
        
        //find layers
        float n = 1.0 - fbm(fs_Pos.x, fs_Pos.y, fs_Pos.z);
        float extrusion = 2.0 * n*n*n;
        vec3 oceanLayer = clamp((2.0 * (0.3 - extrusion)), 0.0, 1.0) * ocean;
        vec3 forestLayer = 5.0 * clamp(extrusion, 0.0, 1.0) * forest;
        vec3 sandLayer = 6.0 * clamp(2.0 * (0.22 - clamp((extrusion - 0.20), 0.0, 1.0)), 0.0, 1.0) * sand;
        vec3 alpineLayer = 2.0 * clamp(10.0 * (extrusion- 0.53), 0.0, 1.0) * alpine;
        vec3 snowLayer = 1.1 * clamp(10.0 * (extrusion- 0.75), 0.0, 1.0) * snow;

        //combine layers
        float r = mix(oceanLayer.r, mix(mix(alpineLayer.r, mix(forestLayer.r, sandLayer.r, 0.5), 0.7), snowLayer.r, 0.5), 0.55);
        float g = mix(oceanLayer.g, mix(mix(alpineLayer.g, mix(forestLayer.g, sandLayer.g, 0.5), 0.7), snowLayer.g, 0.5), 0.55);
        float b = mix(oceanLayer.b, mix(mix(alpineLayer.b, mix(forestLayer.b, sandLayer.b, 0.5), 0.7), snowLayer.b, 0.5), 0.55);

        vec3 final = vec3(r, g, b);

        //building
        float n1 = perlinNoise3D(fs_Pos.xyz * 20.0);
        float n2 = perlinNoise3D(fs_Pos.xyz * 30.0);
        vec3 cityColor = vec3(1, 1, 0.91);
        vec3 layerb2 = 0.5 / n1 * cityColor + 0.5 / n2 * cityColor;
        float n3 = rand3D(fs_Pos.xyz * 100.0);

        n = gain(n, 0.45);
        if(u_Mode == 0) {
            if(n > -0.79 && n < -0.78) {
                final = final + 0.5 * cityColor * layerb2 * layerb2 / 100.0 * pow((1.0 - lightIntensity), 6.0);
            }
    
            out_Col = vec4(final.rgb * lightIntensity, diffuseColor.a);
        }
        
        if(u_Mode == 1) {
            //gradient
            float PI  = 3.141592653589793;
            r = 0.7 + 0.5 * cos(2.0 * PI * (1.0 * diffuseTerm + 3.0));
            g = 0.3 + 0.7 * cos(2.0 * PI * (1.0 * diffuseTerm + 2.25));
            b = 0.5 + 0.5 * cos(2.0 * PI * (1.0 * diffuseTerm + 2.25));
            out_Col = vec4(r, g, b, 1.0);

        }

        if(u_Mode == 2) {
            if(n > -0.79 && n < -0.78) {
                final = final + 0.5 * cityColor * layerb2 * layerb2 / 100.0 * pow((1.0 - ambientTerm), 6.0);
            }
    
            out_Col = vec4(final.rgb * ambientTerm, diffuseColor.a);
        }
        

        
        
}
