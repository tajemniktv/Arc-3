import aperture;
import buffers.scene;
import lib.common;
import lib.light.brdf;
import lib.material;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.shadow;

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
FragmentOutput lightingSky(float2 pos : SV_Position) {
    FragmentOutput output;
    uint2 uv = uint2(pos);

    float depth = mainDepthTex[uv];
    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene.taa_jitter;

    float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = project(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);
    float3 fragLocalDir = normalize(localPos);

    //float4 albedo = texAlbedoGB[uv];
    uint2 normalData = texNormalGB[uv];
    uint2 matLightData = texMatLightGB[uv];

    float4 specularData = unpackUnorm4x8ToFloat(matLightData.r);
    float roughness = mat_roughness(specularData.r);
    float roughL = roughness*roughness;

    //float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normalData.r).xyz * 2.0 - 1.0);
    float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normalData.g).xyz * 2.0 - 1.0);

    float4 lightData = unpackUnorm4x8ToFloat(matLightData.g);
    //float2 lmcoord = light.rg;
    float lmcoord_y = lightData.g*lightData.g;
    float occlusion = lightData.b;
    
    float NoV = max(dot(tex_normal, -fragLocalDir), 0.0);

    int shadowCascade;
    float3 shadowPos;
    float3 shadowViewPos = mul3(ap.celestial.view, localPos);
    GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);

    float shadow = 1.0;
    if (shadowCascade >= 0)
        shadow = SampleShadow(shadowPos, shadowCascade);

    float3 skyPos = getSkyPosition(localPos);

    float NoLm_sun = max(dot(tex_normal, scene.SunLocalDir), 0.0);
    float3 sunTransmit = sampleSkyTransmit(skyPos, scene.SunLocalDir);
    float3 lightSun = NoLm_sun * sunTransmit * scene.SunColor;

    float NoLm_moon = max(dot(tex_normal, scene.MoonLocalDir), 0.0);
    float3 moonTransmit = sampleSkyTransmit(skyPos, scene.MoonLocalDir);
    float3 lightMoon = NoLm_moon * moonTransmit * scene.MoonColor;

    float3 ambient = sampleSkyIrradiance(tex_normal) * lmcoord_y * occlusion;

    // float3 H_sun = normalize();
    // float LoH_sun = max(dot(scene.SunLocalDir, H_sun), 0.0);
    // float diffuseSun = SampleLightDiffuse(NoV, NoLm_sun, LoH_sun, roughL);

    output.diffuse = (lightSun + lightMoon) / PI * shadow + ambient;
    output.specular = 0.0;

    return output;
}
