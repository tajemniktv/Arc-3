import aperture;
import buffers.scene;
import lib.common;
import lib.point_lights;

extern static const float BLOCK_LUX = 200.0;
extern static const bool PointLight_Enabled;
extern static const bool TAA_Enabled;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float> mainDepthTex;


struct FragmentOutput {
    float3 diffuse : SV_Target0;
    float3 specular : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput lightingBlock(float2 pos : SV_Position) {
    FragmentOutput output;
    uint2 uv = uint2(pos);

    //float4 albedo = texAlbedoGB[uv];
    uint2 normals = texNormalGB[uv];
    uint2 mat_light = texMatLightGB[uv];

    //float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
    float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);

    float4 light = unpackUnorm4x8ToFloat(mat_light.g);
    float lmcoord_x = light.r * light.r;
    //float occlusion = light.b;

    if (PointLight_Enabled) {
        float depth = mainDepthTex[uv];
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene.taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        if (shadowPoint_isInBounds(localPos)) {
            lmcoord_x = 0.0;
        }
    }

    output.diffuse = lmcoord_x / PI * BLOCK_LUX;
    output.specular = 0.0;

    return output;
}
