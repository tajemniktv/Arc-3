import aperture;
import buffers.scene;
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
extern static const bool World_HasSky;
extern static const bool Lighting_GI_Enabled;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float3> texDiffuse;
Sampler2D<float3> texSpecular;
Sampler2D<float4> texIndirectDiffuse;
Sampler2D<float> mainDepthTex;


[[shader("fragment")]]
float4 lightingFinal(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = mainDepthTex[uv];

    float3 color = 0.0;
    if (depth < 1.0) {
        // uint2 normals = texNormalGB[uv];
        // float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
        // float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);

        uint2 matLightData = texMatLightGB[uv];
        float4 specularData = unpackUnorm4x8ToFloat(matLightData.r);
        float4 lightData = unpackUnorm4x8ToFloat(matLightData.g);

        float occlusion = lightData.b;
        
        float3 ambientColor = float3(Lighting_Ambient_Red, Lighting_Ambient_Green, Lighting_Ambient_Blue);
        const float3 ambient = Lighting_Ambient_Brightness * ambientColor * occlusion;
        float4 albedo = texAlbedoGB[uv];
        float3 diffuse = texDiffuse[uv];
        float3 specular = texSpecular[uv];
        float3 indirect = 0.0;
        if (Lighting_GI_Enabled) {
            indirect = texIndirectDiffuse[uv].rgb;
        }
        float emission = mat_emission(specularData) * BLOCK_LUX;

        albedo.rgb = RgbToLinear(albedo.rgb);
        if (Debug_WhiteWorld) albedo.rgb = 0.85;

        color = albedo.rgb * (diffuse + indirect + emission + ambient) + specular;
    }
    else if (World_HasSky) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord += scene.taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = normalize(localPos);

        color = sampleSkyFinal(localPos, viewLocalDir, false);
    }

    return float4(color, 1.0);
}
