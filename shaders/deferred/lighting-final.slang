import aperture;
import buffers.scene;
import lib.common;
import lib.sky.common;
import lib.sky.sample_view;
import lib.material;

extern static const float BLOCK_LUX;
extern static const bool Debug_WhiteWorld;

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

    float3 color;
    if (depth == 1.0) {
        float2 texcoord = pos / ap.game.screenSize;
        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = normalize(localPos);

        float3 skyPos = getSkyPosition(0.0);

        color = sampleSkyView(skyPos, viewLocalDir, scene.SunLocalDir);
    }
    else {
        // uint2 normals = texNormalGB[uv];
        // float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
        // float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);
        float4 specularData = unpackUnorm4x8ToFloat(texMatLightGB[uv].r);
        
        float3 ambient = 0.02;
        float4 albedo = texAlbedoGB[uv];
        float3 diffuse = texDiffuse[uv];
        float3 specular = texSpecular[uv];
        float emission = mat_emission(specularData) * BLOCK_LUX;

        albedo.rgb = RgbToLinear(albedo.rgb);
        if (Debug_WhiteWorld) albedo.rgb = 0.85;

        color = albedo.rgb * (diffuse + emission + ambient) + specular;
    }

    return float4(color, 1.0);
}
