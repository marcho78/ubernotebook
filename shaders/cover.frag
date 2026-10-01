#version 440
// A notebook's cover: its material (pebbled leather with stitching, woven
// linen, kraft board, smooth card, or a composition book's marbling) in its
// color, lit softly from the top left, with rounded corners and a spine at
// the left edge (cloth tape, or a hardcover's hinge).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // px
    vec4 base;          // the cover's color
    float material;     // 0 leather, 1 linen, 2 kraft, 3 smooth, 4 composition
    float radius;       // corner radius, px
    float spine;        // 0 none, 1 cloth tape, 2 hinge
    float stitch;       // 0/1: stitching around the edge (leather)
    float dpr;
    float seed;
    float inside;       // 1: the inside of the cover (smooth, lighter)
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + seed);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        a *= 0.5;
    }
    return v;
}

// Distance to the nearest point of a jittered grid: leather's pebbles.
float cells(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float d = 8.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 g = vec2(float(x), float(y));
            vec2 o = vec2(hash(i + g), hash(i + g + 31.7));
            d = min(d, length(g + o - f));
        }
    }
    return d;
}

float roundedBox(vec2 p, vec2 half_, float r) {
    vec2 q = abs(p) - half_ + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec3 c = base.rgb;
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));

    if (inside > 0.5) {
        // The inside of a cover: smooth card, lighter than the outside.
        c += (noise(px * 0.8) - 0.5) * 0.02;
    } else if (material < 0.5) {
        // Leather: pebbles, each lit from above, and a little sheen.
        float cell = cells(px * 0.16);
        float pebble = smoothstep(0.05, 0.75, cell);
        float lit = cells((px + vec2(-0.8, -0.8)) * 0.16) - cell;
        c *= 0.9 + pebble * 0.12;
        c += lit * 0.22 * (0.4 + lum);
        c += (fbm(px * 0.02) - 0.5) * 0.08;
    } else if (material < 1.5) {
        // Linen: threads one way and the other, a little uneven.
        float wx = sin(px.x * 1.9 + noise(px * 0.15) * 2.0) * 0.5 + 0.5;
        float wy = sin(px.y * 1.9 + noise(px.yx * 0.15) * 2.0) * 0.5 + 0.5;
        float weave = mix(wx, wy, step(0.5, fract((floor(px.x * 0.6) + floor(px.y * 0.6)) * 0.5)));
        c *= 0.93 + weave * 0.1;
        c += (noise(px * 0.05) - 0.5) * 0.05;
    } else if (material < 2.5) {
        // Kraft board: fibers and flecks.
        float f1 = noise(vec2(px.x * 0.05, px.y * 0.8));
        float f2 = noise(vec2(px.x * 0.8, px.y * 0.05) + 13.0);
        float strands = smoothstep(0.72, 0.95, f1) + smoothstep(0.75, 0.96, f2);
        c = mix(c, c * 0.8, clamp(strands, 0.0, 1.0) * 0.4);
        float fleck = step(0.992, hash(floor(px * 0.7)));
        c = mix(c, c * 0.55, fleck * 0.6);
        c += (fbm(px * 0.03) - 0.5) * 0.07;
    } else if (material < 3.5) {
        // Smooth card: barely any texture.
        c += (noise(px * 0.9) - 0.5) * 0.018 + (fbm(px * 0.01) - 0.5) * 0.04;
    } else {
        // Composition marbling: pale swirls through the cover's color.
        vec2 q = px * 0.035;
        vec2 warp = vec2(fbm(q * 0.6 + vec2(3.1, 7.7)), fbm(q * 0.6 + vec2(8.3, 2.8)));
        float m = fbm(q + warp * 2.4);
        // Pale islands with ragged edges, and fine veins between them.
        float islands = smoothstep(0.52, 0.56, m);
        float veins = 1.0 - smoothstep(0.0, 0.018, abs(fbm(q * 2.3 + warp * 3.0) - 0.5));
        float speck = step(0.83, noise(px * 0.55)) * 0.7;
        float marble = clamp(max(islands, max(veins * 0.85, speck * (1.0 - islands))), 0.0, 1.0);
        vec3 pale = vec3(0.94, 0.93, 0.9);
        c = mix(c, pale, marble * 0.94);
    }

    // The spine at the left: cloth tape, or a hardcover's hinge groove.
    if (inside < 0.5 && spine > 0.5 && spine < 1.5) {
        float w = min(34.0, size.x * 0.13);
        float t = step(px.x, w);
        vec3 tape = base.rgb * 0.55 + (noise(vec2(px.x * 1.5, px.y * 0.1)) - 0.5) * 0.06;
        c = mix(c, tape, t);
        c *= 1.0 - (1.0 - smoothstep(0.0, 3.0, abs(px.x - w))) * 0.35;
    } else if (inside < 0.5 && spine > 1.5) {
        float g = abs(px.x - min(22.0, size.x * 0.08));
        c *= 1.0 - (1.0 - smoothstep(0.0, 2.2, g)) * 0.35;
        c += (1.0 - smoothstep(0.0, 1.2, abs(px.x - min(22.0, size.x * 0.08) - 2.2))) * 0.06;
    }

    // Stitching around the edge.
    if (inside < 0.5 && stitch > 0.5) {
        float inset = 9.0;
        vec2 d = min(px, size - px);
        float edge = min(d.x, d.y);
        float onLine = 1.0 - smoothstep(0.5, 1.2, abs(edge - inset));
        float along = d.x < d.y ? px.y : px.x;
        float dash = step(0.35, fract(along / 7.0));
        c = mix(c, mix(c, vec3(0.92, 0.88, 0.78), 0.55), onLine * dash);
    }

    // Light from the top left, and the edges falling away.
    vec2 uv = qt_TexCoord0;
    c *= 0.9 + 0.16 * (1.0 - uv.y * 0.7) * (1.0 - uv.x * 0.4);
    vec2 e = min(px, size - px);
    float rim = 1.0 - smoothstep(0.0, 5.0, min(e.x, e.y));
    c = mix(c, c * 0.72, rim * 0.6);

    // Rounded corners, antialiased.
    float r = min(radius, min(size.x, size.y) * 0.5);
    float dist = roundedBox(px - size * 0.5, size * 0.5, r);
    float a = clamp(0.5 - dist * max(dpr, 1.0), 0.0, 1.0);

    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0) * a * base.a * qt_Opacity;
}
