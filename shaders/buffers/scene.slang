extern static const int SHADOW_CASCADE_COUNT;

struct SceneBuffer {
    float2 taa_jitter;
    float3 SunColor;
    float3 SunLocalDir;
    float3 MoonColor;
    float3 MoonLocalDir;
    float3 SkyLightLocalDir;
    float exposure;

    float2 shadowViewMin[SHADOW_CASCADE_COUNT]; // 2*4
    float2 shadowViewMax[SHADOW_CASCADE_COUNT]; // 2*4
};
