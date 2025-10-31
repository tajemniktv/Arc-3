import aperture;
import buffers.scene;
// import buffers.settings;
import lib.common;
import lib.material.pbr;
import lib.sky.sample_final;

extern static const float BLOCK_LUX;
extern static const bool TAA_Enabled;
extern static const bool Debug_WhiteWorld;
extern static const float Lighting_Ambient_Brightness;
extern static const float Lighting_Ambient_Red;
extern static const float Lighting_Ambient_Green;
extern static const float Lighting_Ambient_Blue;
extern static const bool Lighting_GI_Enabled;
extern static const bool Lighting_LPV_Enabled;
extern static const float Lighting_LPV_Range;
extern static const float Lighting_LPV_Strength;

ConstantBuffer<SceneBuffer> scene;
// ConstantBuffer<SettingsBuffer> settings;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float3> texDiffuse;
Sampler2D<float3> texSpecular;
Sampler2D<float4> texIndirectDiffuse;
Sampler3D<float4> texLpvRadiance;
Sampler2D<float> mainDepthTex;


float3 reconstructLocalPosition(const in float2 texcoord, const in float depth) {
    float3 clip = float3(texcoord, depth) * 2.0 - 1.0;
    float3 view = project(ap.camera.projectionInv, clip);
    return mul3(ap.camera.viewInv, view);
}


[[shader("fragment")]]
float4 lightingFinal(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = mainDepthTex[uv];

    float2 texcoordJittered = (float2(uv) + 0.5) / float2(ap.game.screenSize);
    float2 texcoord = texcoordJittered;
    if (TAA_Enabled) texcoord -= scene.taa_jitter;

    float2 skyTexcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) skyTexcoord += scene.taa_jitter;

    float3 color;
    if (depth == 1.0) {
        float3 clipPos = float3(skyTexcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = normalize(localPos);

        color = sampleSkyFinal(localPos, viewLocalDir, false);
    }
    else {
        // uint2 normals = texNormalGB[uv];
        // float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
        // float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);
        float4 specularData = unpackUnorm4x8ToFloat(texMatLightGB[uv].r);
        float3 localPos = reconstructLocalPosition(texcoord, depth);

        //float occlusion = lightData.b;
        float3 ambientColor = float3(Lighting_Ambient_Red, Lighting_Ambient_Green, Lighting_Ambient_Blue);
        //float3 ambient = (Lighting_Ambient_Brightness * occlusion) * ambientColor;
        float3 ambient = Lighting_Ambient_Brightness * ambientColor;
        float4 albedo = texAlbedoGB[uv];
        float3 diffuse = texDiffuse[uv];
        float3 specular = texSpecular[uv];
        float3 indirect = 0.0;
        if (Lighting_GI_Enabled) {
            indirect = texIndirectDiffuse[uv].rgb;
        }
        if (Lighting_LPV_Enabled && Lighting_LPV_Range > 0.0) {
            float extent = Lighting_LPV_Range;
            float3 gridMin = ap.camera.position - extent;
            float3 gridSize = float3(extent * 2.0);
            float3 lpvCoord = (localPos - gridMin) / gridSize;
            if (all(lpvCoord == saturate(lpvCoord))) {
                float3 lpvIrradiance = texLpvRadiance.SampleLevel(lpvCoord, 0.0).rgb;
                indirect += lpvIrradiance * Lighting_LPV_Strength;
            }
        }
        float emission = mat_emission(specularData) * BLOCK_LUX;

        albedo.rgb = RgbToLinear(albedo.rgb);
        if (Debug_WhiteWorld) albedo.rgb = 0.85;

        color = albedo.rgb * (diffuse + indirect + emission + ambient) + specular;
    }

    return float4(color, 1.0);
}
