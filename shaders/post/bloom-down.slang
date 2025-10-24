import aperture;
import lib.common;

extern static const uint MIP_INDEX;

Sampler2D<float3> texSource;


float3 sample_src(const in float2 uv) {
    return texSource.SampleLevel(uv, MIP_INDEX);
}

[[shader("fragment")]]
float3 applyBloomDown(float2 pos : SV_Position) : SV_Target0 {
    uint3 texSrc_size;
    texSource.GetDimensions(MIP_INDEX, texSrc_size.x, texSrc_size.y, texSrc_size.z);
    float2 srcPixelSize = rcp(texSrc_size.xy);

    float2 uv = 2.0 * pos * srcPixelSize;

    float3 a = sample_src(fma(srcPixelSize, float2(-2.0, +2.0), uv));
    float3 b = sample_src(fma(srcPixelSize, float2( 0.0, +2.0), uv));
    float3 c = sample_src(fma(srcPixelSize, float2(+2.0, +2.0), uv));

    float3 d = sample_src(fma(srcPixelSize, float2(-2.0, 0.0), uv));
    float3 e = sample_src(fma(srcPixelSize, float2( 0.0, 0.0), uv));
    float3 f = sample_src(fma(srcPixelSize, float2(+2.0, 0.0), uv));

    float3 g = sample_src(fma(srcPixelSize, float2(-2.0, -2.0), uv));
    float3 h = sample_src(fma(srcPixelSize, float2( 0.0, -2.0), uv));
    float3 i = sample_src(fma(srcPixelSize, float2(+2.0, -2.0), uv));

    float3 j = sample_src(fma(srcPixelSize, float2(-1.0, +1.0), uv));
    float3 k = sample_src(fma(srcPixelSize, float2(+1.0, +1.0), uv));
    float3 l = sample_src(fma(srcPixelSize, float2(-1.0, -1.0), uv));
    float3 m = sample_src(fma(srcPixelSize, float2(+1.0, -1.0), uv));

    float3 color =   e * 0.12500;
    color += (a+c+g+i) * 0.03125;
    color += (b+d+f+h) * 0.06250;
    color += (j+k+l+m) * 0.12500;

    // color = clamp(color, 0.0, 65000.0);
    return color;
}
