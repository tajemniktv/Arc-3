import aperture;
import lib.common;

extern static const float Effect_Bloom_Strength = 0.04;
extern static const uint BLOOM_INDEX;
extern static const uint MIP_INDEX;

Sampler2D<float3> texSource;
Sampler2D<float3> texBloom;


[[shader("fragment")]]
float3 applyBloomDown(float2 pos : SV_Position) : SV_Target0 {
    uint3 texSrc_size;
    texSource.GetDimensions(MIP_INDEX, texSrc_size.x, texSrc_size.y, texSrc_size.z);
    float2 srcPixelSize = rcp(texSrc_size.xy);

    float2 uv = 2.0 * pos * srcPixelSize;

    float3 a = texSource.SampleLevel(fma(srcPixelSize, float2(-2.0, +2.0), uv), MIP_INDEX);
    float3 b = texSource.SampleLevel(fma(srcPixelSize, float2( 0.0, +2.0), uv), MIP_INDEX);
    float3 c = texSource.SampleLevel(fma(srcPixelSize, float2(+2.0, +2.0), uv), MIP_INDEX);

    float3 d = texSource.SampleLevel(fma(srcPixelSize, float2(-2.0, 0.0), uv), MIP_INDEX);
    float3 e = texSource.SampleLevel(fma(srcPixelSize, float2( 0.0, 0.0), uv), MIP_INDEX);
    float3 f = texSource.SampleLevel(fma(srcPixelSize, float2(+2.0, 0.0), uv), MIP_INDEX);

    float3 g = texSource.SampleLevel(fma(srcPixelSize, float2(-2.0, -2.0), uv), MIP_INDEX);
    float3 h = texSource.SampleLevel(fma(srcPixelSize, float2( 0.0, -2.0), uv), MIP_INDEX);
    float3 i = texSource.SampleLevel(fma(srcPixelSize, float2(+2.0, -2.0), uv), MIP_INDEX);

    float3 j = texSource.SampleLevel(fma(srcPixelSize, float2(-1.0, +1.0), uv), MIP_INDEX);
    float3 k = texSource.SampleLevel(fma(srcPixelSize, float2(+1.0, +1.0), uv), MIP_INDEX);
    float3 l = texSource.SampleLevel(fma(srcPixelSize, float2(-1.0, -1.0), uv), MIP_INDEX);
    float3 m = texSource.SampleLevel(fma(srcPixelSize, float2(+1.0, -1.0), uv), MIP_INDEX);

    float3 color =   e * 0.12500;
    color += (a+c+g+i) * 0.03125;
    color += (b+d+f+h) * 0.06250;
    color += (j+k+l+m) * 0.12500;

    color = clamp(color, 0.0, 65000.0);
    return color;
}


[[shader("fragment")]]
float3 applyBloomUp(float2 pos : SV_Position) : SV_Target0 {
    uint3 texSrc_size;
    texBloom.GetDimensions(MIP_INDEX, texSrc_size.x, texSrc_size.y, texSrc_size.z);
    float2 srcPixelSize = rcp(texSrc_size.xy);

    float2 uv = 0.5 * pos * srcPixelSize;

    float3 a = texBloom.SampleLevel(fma(srcPixelSize, float2(-1.0, +1.0), uv), MIP_INDEX);
    float3 b = texBloom.SampleLevel(fma(srcPixelSize, float2( 0.0, +1.0), uv), MIP_INDEX);
    float3 c = texBloom.SampleLevel(fma(srcPixelSize, float2(+1.0, +1.0), uv), MIP_INDEX);

    float3 d = texBloom.SampleLevel(fma(srcPixelSize, float2(-1.0,  0.0), uv), MIP_INDEX);
    float3 e = texBloom.SampleLevel(fma(srcPixelSize, float2( 0.0,  0.0), uv), MIP_INDEX);
    float3 f = texBloom.SampleLevel(fma(srcPixelSize, float2(+1.0,  0.0), uv), MIP_INDEX);

    float3 g = texBloom.SampleLevel(fma(srcPixelSize, float2(-1.0, -1.0), uv), MIP_INDEX);
    float3 h = texBloom.SampleLevel(fma(srcPixelSize, float2( 0.0, -1.0), uv), MIP_INDEX);
    float3 i = texBloom.SampleLevel(fma(srcPixelSize, float2(+1.0, -1.0), uv), MIP_INDEX);

    float3 color =   e * 0.2500;
    color += (b+d+f+h) * 0.1250;
    color += (a+c+g+i) * 0.0625;

    if (BLOOM_INDEX == 0u) {
        color = color * Effect_Bloom_Strength + texSource[int2(pos)];
    }

    color = clamp(color, 0.0, 65000.0);
    return color;
}
