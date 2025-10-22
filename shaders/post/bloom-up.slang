import aperture;
import lib.common;

extern static const float Effect_Bloom_Strength = 0.04;
extern static const uint BLOOM_INDEX;
extern static const uint MIP_INDEX;

Sampler2D<float3> texBloom;
Sampler2D<float3> TEX_SRC;

float3 sample_src(const in float2 uv) {
    return texBloom.SampleLevel(uv, MIP_INDEX);
}

[[shader("fragment")]]
float3 applyBloomUp(float2 pos : SV_Position) : SV_Target0 {
    uint3 texSrc_size;
    texBloom.GetDimensions(MIP_INDEX, texSrc_size.x, texSrc_size.y, texSrc_size.z);
    float2 srcPixelSize = rcp(texSrc_size.xy);

    float2 uv = 0.5 * pos * srcPixelSize;

    float3 a = sample_src(fma(srcPixelSize, float2(-1.0, +1.0), uv));
    float3 b = sample_src(fma(srcPixelSize, float2( 0.0, +1.0), uv));
    float3 c = sample_src(fma(srcPixelSize, float2(+1.0, +1.0), uv));

    float3 d = sample_src(fma(srcPixelSize, float2(-1.0,  0.0), uv));
    float3 e = sample_src(fma(srcPixelSize, float2( 0.0,  0.0), uv));
    float3 f = sample_src(fma(srcPixelSize, float2(+1.0,  0.0), uv));

    float3 g = sample_src(fma(srcPixelSize, float2(-1.0, -1.0), uv));
    float3 h = sample_src(fma(srcPixelSize, float2( 0.0, -1.0), uv));
    float3 i = sample_src(fma(srcPixelSize, float2(+1.0, -1.0), uv));

    float3 outColor = e * 4.0;
    outColor += (b+d+f+h) * 2.0;
    outColor += (a+c+g+i);
    outColor *= 1.0 / 16.0;

    if (BLOOM_INDEX == 0u) {
        outColor *= Effect_Bloom_Strength;

        outColor += TEX_SRC[int2(pos)];
        outColor = clamp(outColor, 0.0, 65.0);
    }

    return outColor;
}
