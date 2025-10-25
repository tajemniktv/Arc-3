import aperture;
import buffers.scene;
import lib.common;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;

import lib.sampling.ERP;

extern static const bool TAA_Enabled;
extern static const uint SHADOW_CASCADE_COUNT = 4;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float> mainDepthTex;
Sampler2DArrayShadow solidShadowMapFiltered;


void GetShadowProjection(const in float3 shadowViewPos, out int cascadeIndex, out float3 shadowPos) {
    cascadeIndex = -1;
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        shadowPos = mul3(ap.celestial.projection[i], shadowViewPos).xyz;

        const float3 cascadePadding = float3(EPSILON, EPSILON, 0.0);

        if (all(clamp(shadowPos, -1.0 + cascadePadding, 1.0 - cascadePadding) == shadowPos)) {
            cascadeIndex = i;
            shadowPos = shadowPos * 0.5 + 0.5;
            break;
        }
    }
}

float SampleShadow(in float3 shadowPos, const in int shadowCascade) {
    if (any(saturate(shadowPos) != shadowPos)) return 1.0;

    float zRange = ap.celestial.projectionInv[shadowCascade]._33;
    const float bias = 0.02 / zRange;
    
    float3 shadowCoord = float3(shadowPos.xy, shadowCascade);
    return solidShadowMapFiltered.SampleCmp(shadowCoord, shadowPos.z + bias).r;
}

struct FragmentOutput {
    float3 diffuse : SV_Target0;
    float3 specular : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput lightingSky(float2 pos : SV_Position) {
    FragmentOutput output;
    uint2 uv = uint2(pos);

    float depth = mainDepthTex[uv];
    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene.taa_jitter;

    float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = unproject(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);

    //float4 albedo = texAlbedoGB[uv];
    uint2 normals = texNormalGB[uv];
    uint2 mat_light = texMatLightGB[uv];

    //float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
    float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);
    // bool hasNormal = any(tex_normal > -1.0);
    // if (hasNormal) tex_normal = normalize(tex_normal);

    float4 light = unpackUnorm4x8ToFloat(mat_light.g);
    //float2 lmcoord = light.rg;
    float lmcoord_y = light.g*light.g;
    float occlusion = light.b;
    
    int shadowCascade;
    float3 shadowPos;
    float3 shadowViewPos = mul3(ap.celestial.view, localPos);
    GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);

    float shadow = 1.0;
    if (shadowCascade >= 0)
        shadow = SampleShadow(shadowPos, shadowCascade);

    float3 skyPos = getSkyPosition(localPos);

    float NoLm_sun = 0.0, NoLm_moon = 0.0;
    // if (hasNormal) {
        NoLm_sun = max(dot(tex_normal, scene.SunLocalDir), 0.0);
        NoLm_moon = max(dot(tex_normal, scene.MoonLocalDir), 0.0);
    // }

    float3 sunTransmit = sampleSkyTransmit(skyPos, scene.SunLocalDir);
    float3 lightSun = NoLm_sun * sunTransmit * scene.SunColor;

    float3 moonTransmit = sampleSkyTransmit(skyPos, scene.MoonLocalDir);
    float3 lightMoon = NoLm_moon * moonTransmit * scene.MoonColor;

    float3 ambient = sampleSkyIrradiance(tex_normal) * lmcoord_y * occlusion;

    output.diffuse = (lightSun + lightMoon) / PI * shadow + ambient;
    output.specular = 0.0;

    return output;
}
