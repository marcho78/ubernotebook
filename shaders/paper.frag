#version 440
// Omanote's paper: the sheet's color and grain, and its printed pattern
// (ruled lines, grid, dots, graph), drawn per pixel so it stays crisp at any
// zoom. Rows line up with the editor's: row k's rule sits `rule` px below the
// top of the row, which is where the text's baselines are.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // the item, in px
    float pitch;        // row height, px
    float originY;      // where the first row starts, in item px (moves as the page scrolls)
    float rule;         // a rule's offset below its row's top, px
    float marginX;      // the margin rule's x, px (0: none)
    float pattern;      // 0 blank, 1 ruled, 2 grid, 3 dots, 4 graph, 5 legal
    float lineWidth;    // px
    float grain;        // 0..1 paper texture
    float fiber;        // 0..1 kraft fibers
    float dpr;          // device pixels per px
    float scroll;       // how far the page has scrolled, px (moves the grain with it)
    vec4 paper;
    vec4 lineColor;
    vec4 marginColor;
    vec4 headColor;     // the rule under the header (title) area
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
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

// How much of this device pixel a line of width w (px) covers, when the
// pixel's center is d px from the line's. Exact box coverage keeps one-pixel
// rules one pixel wide when they sit on pixel centers.
float lineAt(float d, float w) {
    float scale = max(dpr, 1.0);
    float dd = d * scale;
    float ww = max(w * scale, 1.0);
    return clamp(min(dd + ww * 0.5, 0.5) - max(dd - ww * 0.5, -0.5), 0.0, 1.0);
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    // Content coordinates: the grain and fibers travel with the page.
    vec2 cp = vec2(px.x, px.y + scroll);

    vec3 color = paper.rgb;

    // Grain: fine speckle plus soft mottling, lighter and darker than the paper.
    float g = (noise(cp * 0.9) - 0.5) * 0.55 + (noise(cp * 0.21) - 0.5) * 0.35 + (noise(cp * 0.018) - 0.5) * 0.3;
    color += g * 0.028 * grain;

    // Fibers: long thin strands, like kraft or recycled paper.
    if (fiber > 0.0) {
        float f1 = noise(vec2(cp.x * 0.04, cp.y * 0.9));
        float f2 = noise(vec2(cp.x * 0.7, cp.y * 0.05) + 17.0);
        float strands = smoothstep(0.78, 0.95, f1) + smoothstep(0.8, 0.96, f2);
        color = mix(color, color * 0.82, clamp(strands, 0.0, 1.0) * 0.35 * fiber);
    }

    float ink = 0.0;
    vec4 ic = lineColor;

    float y = px.y - originY;         // relative to the first row
    float below = step(0.0, y);       // the pattern starts at the first row

    if (pattern > 0.5 && pattern < 1.5 || pattern > 4.5) {
        // Ruled (and legal): one rule per row.
        float d = mod(y - rule + pitch * 0.5, pitch) - pitch * 0.5;
        ink = lineAt(d, lineWidth) * below;
    } else if (pattern > 1.5 && pattern < 2.5) {
        // Grid: squares one row high, rows on the rules.
        float dy = mod(y - rule + pitch * 0.5, pitch) - pitch * 0.5;
        float dx = mod(px.x - marginX + pitch * 0.5, pitch) - pitch * 0.5;
        ink = max(lineAt(dy, lineWidth), lineAt(dx, lineWidth)) * below;
    } else if (pattern > 2.5 && pattern < 3.5) {
        // Dots on the rules, one row apart.
        float dy = mod(y - rule + pitch * 0.5, pitch) - pitch * 0.5;
        float dx = mod(px.x - marginX + pitch * 0.5, pitch) - pitch * 0.5;
        float r = length(vec2(dx, dy));
        float dotR = max(lineWidth * 1.3, 1.2);
        ink = (1.0 - smoothstep(dotR - 0.5 / max(dpr, 1.0), dotR + 0.5 / max(dpr, 1.0), r)) * below;
    } else if (pattern > 3.5 && pattern < 4.5) {
        // Graph: a fine grid of half rows, stronger on every row.
        float step2 = pitch * 0.5;
        float dy = mod(y - rule + step2 * 0.5, step2) - step2 * 0.5;
        float dx = mod(px.x - marginX + step2 * 0.5, step2) - step2 * 0.5;
        float fine = max(lineAt(dy, lineWidth * 0.8), lineAt(dx, lineWidth * 0.8)) * 0.55;
        float dY = mod(y - rule + pitch * 0.5, pitch) - pitch * 0.5;
        float dX = mod(px.x - marginX + pitch * 0.5, pitch) - pitch * 0.5;
        float major = max(lineAt(dY, lineWidth * 1.1), lineAt(dX, lineWidth * 1.1));
        ink = max(fine, major) * below;
    }

    color = mix(color, ic.rgb, ink * ic.a);

    // The header rule: where the title area ends.
    if (headColor.a > 0.0) {
        float hd = px.y - (originY - pitch + rule);
        float head = lineAt(hd, lineWidth * 1.6);
        color = mix(color, headColor.rgb, head * headColor.a);
    }

    // The margin rule (double for legal pads).
    if (marginX > 0.0 && marginColor.a > 0.0 && (pattern > 0.5 && pattern < 1.5 || pattern > 4.5)) {
        float m = lineAt(px.x - marginX, lineWidth * 1.2);
        if (pattern > 4.5) m = max(m, lineAt(px.x - marginX - 4.0, lineWidth * 1.2));
        color = mix(color, marginColor.rgb, m * marginColor.a);
    }

    fragColor = vec4(color, 1.0) * paper.a * qt_Opacity;
}
