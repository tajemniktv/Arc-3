import aperture;
import lib.common;
import lib.noise.bayer;

extern static const float ditherScale = 0.5;

Sampler2D<float4> texFinal;

[[shader("fragment")]]
float4 main(float2 pos : SV_Position) : SV_Target0 {
    float3 color = texFinal[int2(pos)].rgb;

    color = LinearToRgb(color);

    static const float dither_scale = 2.0 * (1.0/255.0);
    float dither = GetBayerValue(int2(pos)) - 0.5;
    color += dither * dither_scale;

    return float4(color, 1.0);
}
