import aperture;
import buffers.scene;
import lib.common;
import lib.material.pbr;
import lib.sky.sample_final;

extern static const float BLOCK_LUX;
extern static const bool TAA_Enabled;
extern static const bool Debug_WhiteWorld;
extern static const bool World_HasSky;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float3> texDiffuse;
Sampler2D<float3> texSpecular;
Sampler2D<float> mainDepthTex;


[[shader("fragment")]]
float4 lightingFinal(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = mainDepthTex[uv];

    float3 final = 0.0;
    if (depth < 1.0) {
        // uint2 normals = texNormalGB[uv];
        // float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
        // float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);

        uint2 matLightData = texMatLightGB[uv];
        float4 specularData = unpackUnorm4x8ToFloat(matLightData.r);
        float4 lightData = unpackUnorm4x8ToFloat(matLightData.g);

        float occlusion = lightData.b;

        float4 color = texAlbedoGB[uv];
        float3 diffuse = texDiffuse[uv];
        float3 specular = texSpecular[uv];
        float emission = mat_emission(specularData) * BLOCK_LUX;

        float3 albedo = RgbToLinear(color.rgb);
        if (Debug_WhiteWorld) albedo = 0.85;

        const float3 ambient = 0.2 * occlusion;
        final = albedo.rgb * (diffuse + emission + ambient) + specular;
    }
    else if (World_HasSky) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord += scene.taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = normalize(localPos);

        final = sampleSkyFinal(localPos, viewLocalDir, false);
    }

    return float4(final, 1.0);
}
