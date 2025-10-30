Sampler2D<float3> texSource;
Sampler2D<float4> texWeather;


[[shader("fragment")]]
float4 applyOverlays(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);

    float3 color = texSource[uv];
    float4 weather = texWeather[uv];

    color.rgb += weather.rgb * 0.25;

    return float4(color, 1.0);
}
