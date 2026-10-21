#version 440

// A poster in its card: the picture cropped to fill the card (as Image.PreserveAspectCrop would) with the
// card's rounded corners, in one pass. Cheaper than a layer with a mask: no offscreen texture per card.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // card size in px
    float radius;   // corner radius in px
    vec2 crop;      // the part of the picture shown, per axis (1: all of it)
};

layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 uv = (qt_TexCoord0 - 0.5) * crop + 0.5;
    vec4 color = texture(source, uv);

    // rounded rectangle, anti-aliased over about a pixel
    vec2 p = qt_TexCoord0 * size;
    vec2 q = abs(p - size * 0.5) - (size * 0.5 - vec2(radius));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float inside = 1.0 - smoothstep(-0.5, 0.5, d);

    fragColor = color * inside * qt_Opacity;
}
