import aperture;

Sampler2D texFinal;

[[shader("fragment")]]
float4 main(float2 pos : SV_Position) : SV_Target0 {
    return texFinal[int2(pos)];
}
