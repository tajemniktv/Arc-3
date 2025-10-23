import aperture;

static const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);


float InterleavedGradientNoise(const in float2 pixel) {
    float x = dot(pixel, magic.xy);
    return fract(magic.z * fract(x));
}

float InterleavedGradientNoiseTime(const in float2 pixel) {
    float2 uv = pixel + ap.timing.frameCounter * 5.588238;
    return fract(magic.z * fract(dot(magic.xy, uv)));
}
