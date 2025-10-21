import aperture;

Sampler2D<float4> texSource;

[[shader("fragment")]]
float3 copyToFinal(float2 pos : SV_Position) : SV_Target0 { 
    return texSource[int2(pos)].rgb;
}
