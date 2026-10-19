#version 440

// Flux glass panel: samples the panel's own region of the pre-blurred backdrop, tints it, rounds the
// corners with a signed distance field and adds a 1 px top highlight. No blur happens here.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 region;    // panel rect in the backdrop, normalized: x, y, width, height
    vec2 size;      // panel size in px
    float radius;   // corner radius in px
    vec4 tint;      // rgb + tint opacity (straight, not premultiplied)
    float highlight;
};

layout(binding = 1) uniform sampler2D source;

void main()
{
    // 1. the blurred backdrop under this pixel (the backdrop is opaque)
    vec3 bg = texture(source, region.xy + qt_TexCoord0 * region.zw).rgb;

    // 2. tint
    vec3 color = mix(bg, tint.rgb, tint.a);

    // 3. rounded-rectangle mask, distances in px from the panel center
    vec2 px = qt_TexCoord0 * size;
    vec2 p = px - size * 0.5;
    float r = min(radius, 0.5 * min(size.x, size.y));
    float d = length(max(abs(p) - (size * 0.5 - r), 0.0)) - r;
    float alpha = clamp(0.5 - d, 0.0, 1.0);

    // 4. top highlight: white at 10 % over the first pixel row
    if (highlight > 0.0 && px.y < 1.0)
        color = mix(color, vec3(1.0), 0.10);

    // 5. premultiplied output
    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
