import aperture;
import buffers.scene;
import lib.common;
import lib.light.fresnel;
import lib.light.brdf;
import lib.material.pbr;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_view;
import lib.shadow;

extern static const bool TAA_Enabled;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float> mainDepthTex;


struct SurfaceData {
    float3 normal;
    float3 f0;
    float roughL;
    float3 tint;
    // bool is_metal;

    // float3 viewDir;
    // float NoVm;
};

struct SkyLightData {
    float3 skyPos;
    float3 localDir;
    float3 color;
};

void SampleCelestial(inout float3 diffuse, inout float3 specular, SkyLightData light, SurfaceData surface, float3 viewDir, float NoVm) {
    float3 transmit = sampleSkyTransmit(light.skyPos, light.localDir);
    float3 H = normalize(light.localDir + viewDir);

    float NoLm = max(dot(surface.normal, light.localDir), 0.0);
    float NoHm = max(dot(surface.normal, H), 0.0);
    float LoHm = max(dot(light.localDir, H), 0.0);
    float VoHm = max(dot(viewDir, H), 0.0);

    //float3 F_VoH = material_fresnel(albedo, f0_metal, roughL, VoHm);
    float3 F_VoH = F_schlickRough(VoHm, surface.f0, surface.roughL);

    float D = SampleLightDiffuse(NoVm, NoLm, LoHm, surface.roughL);
    diffuse += NoLm * D * transmit * light.color * saturate(1.0 - F_VoH);

    float3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F_VoH, surface.roughL);
    specular += NoLm * S * transmit * light.color;// * surface.tint;
}


struct FragmentOutput {
    float3 diffuse : SV_Target0;
    float3 specular : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput lightingSky(float2 pos : SV_Position) {
    FragmentOutput output;
    output.diffuse = 0.0;
    output.specular = 0.0;
    
    uint2 uv = uint2(pos);

    float depth = mainDepthTex[uv];
    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene.taa_jitter;

    float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = project(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);
    float3 viewLocalDir = -normalize(localPos);

    float4 colorData = texAlbedoGB[uv];
    uint2 normalData = texNormalGB[uv];
    uint2 matLightData = texMatLightGB[uv];

    float4 specularData = unpackUnorm4x8ToFloat(matLightData.r);
    float3 albedo = RgbToLinear(colorData.rgb);
    float roughness = mat_roughness(specularData.r);
    float f0_metal = mat_f0_metal(specularData.g);

    // float roughL = roughness*roughness;

    //float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normalData.r).xyz * 2.0 - 1.0);
    float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normalData.g).xyz * 2.0 - 1.0);

    float4 lightData = unpackUnorm4x8ToFloat(matLightData.g);
    //float2 lmcoord = light.rg;
    float lmcoord_y = lightData.g*lightData.g;
    float occlusion = lightData.b;

    SurfaceData surface;
    surface.normal = tex_normal;
    surface.roughL = roughness*roughness;
    bool is_metal = f0_metal > (229.5/255.0);
    surface.f0 = is_metal ? albedo : f0_metal;
    surface.tint = is_metal ? albedo : 1.0;

    SkyLightData light;
    light.skyPos = getSkyPosition(localPos);

    float NoVm = max(dot(tex_normal, viewLocalDir), 0.0);

    int shadowCascade;
    float3 shadowPos;
    float3 shadowViewPos = mul3(ap.celestial.view, localPos);
    GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);

    float shadow = 1.0;
    if (shadowCascade >= 0)
        shadow = SampleShadow(shadowPos, shadowCascade);

    float3 ambient = sampleSkyIrradiance(tex_normal) * lmcoord_y * occlusion;
    
    light.color = scene.SunColor;
    light.localDir = scene.SunLocalDir;
    SampleCelestial(output.diffuse, output.specular, light, surface, viewLocalDir, NoVm);

    light.color = scene.MoonColor;
    light.localDir = scene.MoonLocalDir;
    SampleCelestial(output.diffuse, output.specular, light, surface, viewLocalDir, NoVm);

    output.diffuse = output.diffuse / PI * shadow + ambient;
    output.specular = output.specular * shadow;

    if (mat_isMetal(f0_metal)) output.diffuse *= roughness;

    // TODO: sky reflections
    float3 skyPos = getSkyPosition(localPos);
    float3 fragViewDir = normalize(viewPos);
    float3 viewNormal = mul(float3x3(ap.camera.view), tex_normal);
    float3 reflectViewDir = reflect(fragViewDir, viewNormal);
    float3 reflectLocalDir = mul(float3x3(ap.camera.viewInv), reflectViewDir);
    reflectLocalDir = normalize(reflectLocalDir);

    float3 skyColor = sampleSkyView(skyPos, reflectLocalDir, scene.SunLocalDir);
    float3 F_NoV = F_schlickRough(NoVm, surface.f0, surface.roughL);
    output.specular += F_NoV * skyColor * ((1.0 - roughness) * lmcoord_y);
    output.diffuse *= 1.0 - F_NoV;

    output.specular *= surface.tint;

    return output;
}
