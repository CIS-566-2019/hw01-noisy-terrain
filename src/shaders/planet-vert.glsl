#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform highp int u_Time;
uniform highp int u_Deform;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.


out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;


const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

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

vec3 modifyPoint(vec3 p) {
    float n = 1.0 - fbm(p.x, p.y, p.z);
    n = gain(n, 0.45 + float(u_Deform) * 0.002);
    vec3 extrusion = vec3(2.0 * n*n*n);
    if (n < -0.8) {
        p += 0.55 * extrusion * extrusion * vs_Nor.xyz;
    } else {
        p += 0.5 * vs_Nor.xyz;
    }
    return p;
}

void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation
    fs_Pos = vs_Pos;
    mat3 invTranspose = mat3(u_ModelInvTr);
    
    
    vec4 newPos = vec4(modifyPoint(vs_Pos.xyz), 1.0);

    vec3 tangent = cross(vec3(0.0, 1.0, 0.0), vs_Nor.xyz);
    vec3 bitangent = cross(vs_Nor.xyz, tangent);
    float alpha = 0.001;
    vec3 p1 = vs_Pos.xyz + alpha * tangent;
    vec3 p2 = vs_Pos.xyz + alpha * bitangent;
    vec3 p3 = vs_Pos.xyz - alpha * tangent;
    vec3 p4 = vs_Pos.xyz - alpha * bitangent;

    p1 = modifyPoint(p1);
    p2 = modifyPoint(p2);
    p3 = modifyPoint(p3);
    p4 = modifyPoint(p4);

    fs_Nor = vec4(cross(p2 - p4, p1 - p3), 1.0);
    fs_Nor = vec4(invTranspose * vec3(fs_Nor), 0.0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.
    

    vec4 modelposition = u_Model * newPos;   // Temporarily store the transformed vertex positions for use below
    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertice
}
