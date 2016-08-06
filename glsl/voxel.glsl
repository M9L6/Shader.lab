
// ------------------ channel define
// 0_# tex02 #_0
// ------------------

// https://www.shadertoy.com/view/MdVSDh

#define PI 3.14159265
#define FAR 60.


mat2 rot2(float a) 
{
    vec2 v = sin(vec2(1.570796, 0) + a);
    return mat2(v, -v.y, v.x);
}
vec3 tex3D(sampler2D tex, in vec3 p, in vec3 n) 
{
    n = max(abs(n), 0.001);
    n /= (n.x + n.y + n.z);
    p = (texture2D(tex, p.yz) * n.x + texture2D(tex, p.zx) * n.y + texture2D(tex, p.xy) * n.z).xyz;
    return p * p;
}
vec2 path(in float z) 
{
    float a = sin(z * 0.11);
    float b = cos(z * 0.14);
    return vec2(a * 4. - b * 1.5, b * 1.7 + a * 1.5);
}
float map(vec3 p) 
{
    p.xy -= path(p.z);
    float n = 5. - length(p.xy * vec2(1, .8));
    return min(p.y + 3., n);
}
const float w2h = 2.;
const float mortW = 0.05;
float brickMorter(vec2 p) 
{
    p.x -= step(1., p.y) * .5;
    p = abs(fract(p + vec2(0, .5)) - .5) * 2.;
    return smoothstep(0., mortW, p.x) * smoothstep(0., mortW * w2h, p.y);
}
float brick(vec2 p) 
{
    p = fract(p * vec2(0.5 / w2h, 0.5)) * 2.;
    return brickMorter(p);
}
float bumpSurf3D(in vec3 p, in vec3 n) 
{
    n = abs(n);
    if (n.x > 0.5) p.xy = p.zy;
 else if (n.y > 0.5) p.xy = p.zx;
     return brick(p.xy);
}
vec3 doBumpMap(in vec3 p, in vec3 nor, float bumpfactor) 
{
    const vec2 e = vec2(0.001, 0);
    float ref = bumpSurf3D(p, nor);
    vec3 grad = (vec3(bumpSurf3D(p - e.xyy, nor), bumpSurf3D(p - e.yxy, nor), bumpSurf3D(p - e.yyx, nor)) - ref) / e.x;
    grad -= nor * dot(nor, grad);
    return normalize(nor + grad * bumpfactor);
}
vec3 doBumpMap(sampler2D tx, in vec3 p, in vec3 n, float bf) 
{
    const vec2 e = vec2(0.001, 0);
    mat3 m = mat3(tex3D(tx, p - e.xyy, n), tex3D(tx, p - e.yxy, n), tex3D(tx, p - e.yyx, n));
    vec3 g = vec3(0.299, 0.587, 0.114) * m;
    g = (g - dot(tex3D(tx, p, n), vec3(0.299, 0.587, 0.114))) / e.x;
    g -= n * dot(n, g);
    return normalize(n + g * bf);
}
vec3 voxelTrace(vec3 ro, vec3 rd, out vec3 mask) 
{
    vec3 p = floor(ro) + .5;
    vec3 dRd = 1. / abs(rd);
    rd = sign(rd);
    vec3 side = dRd * (rd * (p - ro) + 0.5);
    mask = vec3(0);
    for (int i = 0; i < 64; i++) 
    {
        if (map(p) < 0.) break;
         mask = step(side, side.yzx) * (1. - step(side.zxy, side));
        side += mask * dRd;
        p += mask * rd;
    }
    return p;
}
float voxShadow(vec3 ro, vec3 rd, float end) 
{
    float shade = 1.0;
    vec3 p = floor(ro) + .5;
    vec3 dRd = 1. / abs(rd);
    rd = sign(rd);
    vec3 side = dRd * (rd * (p - ro) + 0.5);
    vec3 mask = vec3(0);
    float d = 1.;
    for (int i = 0; i < 16; i++) 
    {
        d = map(p);
        if (d < 0. || length(p - ro) > end) break;
         mask = step(side, side.yzx) * (1. - step(side.zxy, side));
        side += mask * dRd;
        p += mask * rd;
    }
    return shade = step(0., d) * .7 + .3;
}
vec4 voxelAO(vec3 p, vec3 d1, vec3 d2) 
{
    vec4 side = vec4(map(p + d1), map(p + d2), map(p - d1), map(p - d2));
    vec4 corner = vec4(map(p + d1 + d2), map(p - d1 + d2), map(p - d1 - d2), map(p + d1 - d2));
    side = step(side, vec4(0));
    corner = step(corner, vec4(0));
    return 1. - (side + side.yzwx + max(corner, side * side.yzwx)) / 3.;
}
float calcVoxAO(vec3 vp, vec3 sp, vec3 rd, vec3 mask) 
{
    vec4 vAO = voxelAO(vp - sign(rd) * mask, mask.zxy, mask.yzx);
    sp = fract(sp);
    vec2 uv = sp.yz * mask.x + sp.zx * mask.y + sp.xy * mask.z;
    return mix(mix(vAO.z, vAO.w, uv.x), mix(vAO.y, vAO.x, uv.x), uv.y);
}
void main() 
{
    //vec2 uv = (1.0 - vUv * 2.0) * vec2(iResolution.x / iResolution.y, -1.0);
    vec2 uv = ((vUv - 0.5) * 2.0) * vec2(iResolution.z, 1.0);
    vec3 lookAt = vec3(0., 0.5, iGlobalTime * 8. + 0.1);
    vec3 camPos = lookAt + vec3(0.0, 0.0, -0.1);
    vec3 lightPos = camPos + vec3(0, 2.5, 8);
    lookAt.xy += path(lookAt.z);
    camPos.xy += path(camPos.z);
    lightPos.xy += path(lightPos.z);
    float FOV = PI / 2.;
    vec3 forward = normalize(lookAt - camPos);
    vec3 right = normalize(vec3(forward.z, 0., -forward.x));
    vec3 up = cross(forward, right);
    vec3 rd = normalize(forward + FOV * uv.x * right + FOV * uv.y * up);
    rd.xy = rot2(path(lookAt.z).x / 24.) * rd.xy;
    vec3 mask;
    vec3 vPos = voxelTrace(camPos, rd, mask);
    vec3 tCube = (vPos - camPos - .5 * sign(rd)) / rd;
    float t = max(max(tCube.x, tCube.y), tCube.z);
    vec3 sceneCol = vec3(0);
    if (t < FAR) 
    {
        vec3 sp = camPos + rd * t;
        vec3 sn = -(mask * sign(rd));
        vec3 snNoBump = sn;
        const float tSize0 = 1. / 4.;
        sn = doBumpMap(iChannel0, sp * tSize0, sn, 0.02);
        sn = doBumpMap(sp, sn, .15);
        float ao = calcVoxAO(vPos, sp, rd, mask);
        vec3 ld = lightPos - sp;
        float lDist = max(length(ld), 0.001);
        ld /= lDist;
        float atten = 1. / (1. + lDist * .2 + lDist * 0.1);
        float ambience = 0.25;
        float diff = max(dot(sn, ld), 0.0);
        float spec = pow(max(dot(reflect(-ld, sn), -rd), 0.0), 32.);
        vec3 texCol = vec3(1, .6, .4) + step(abs(snNoBump.y), .5) * vec3(0, .4, .6);
        texCol *= tex3D(iChannel0, sp * tSize0, sn);
        float shading = voxShadow(sp + snNoBump * .01, ld, lDist);
        sceneCol = texCol * (diff + ambience) + vec3(.7, .9, 1.) * spec;
        sceneCol *= atten * shading * ao;
    }
     sceneCol = mix(sceneCol, vec3(.08, .16, .34), smoothstep(0., .95, t / FAR));
    gl_FragColor = vec4(sqrt(clamp(sceneCol, 0., 1.)), 1.0);
}
