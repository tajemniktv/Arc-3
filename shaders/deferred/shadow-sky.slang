import aperture;
import buffers.scene;
import lib.common;
import lib.noise.hash;
import lib.material.pbr;
import lib.sampling.IGN;
import lib.shadow;

extern static const int SHADOW_PCF_SAMPLES = 3;
extern static const float SSS_BlockRadius = 1.4;
extern static const float SSS_MaxDist = 6.0;
extern static const bool TAA_Enabled;

Sampler2D<float> mainDepthTex;
Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;


float3 GetProjectionScale(const in int cascade) {
    return float3(0.5, 0.5, -0.5) * float3(
        ap.celestial.projection[cascade][0].x,
        ap.celestial.projection[cascade][1].y,
        ap.celestial.projection[cascade][2].z);
}

// [coverage, distance]
float2 SSS_PCF(const in float3 shadowPos, const in int cascade, const in float2 pixelRadius, const in float bias_scale, const in float sss, const in float dither) {
    float seed_pos = hash13(shadowPos * 999.0);

    float angle = fract(dither) * (2.0*PI);
    float s = sin(angle);
    float c = cos(angle);
    float2x2 rotation = float2x2(
         c, s,
        -s, c);

    const float GoldenAngle = PI * (3.0 - sqrt(5.0));
    const float PHI = (1.0 + sqrt(5.0)) / 2.0;

    float shadowFinal = 0.0;
    float distFinal = 0.0;
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;

        float sample_dither = sss * hash13(float3(seed_pos * 999.0, i, ap.timing.frameCounter));
        float sample_bias = bias_scale * pow3(sample_dither);
        //shadowViewPos.z += sssDist;
        
        float2 pcfDiskOffset = r * float2(cos(theta), sin(theta));
        float2 pixelOffset = mul(rotation, pcfDiskOffset) * pixelRadius;
        float3 sampleShadowPos = shadowPos + float3(pixelOffset, sample_bias);

        // shadowFinal += SampleShadow(sampleShadowPos, cascade);

        float3 shadowCoord = float3(sampleShadowPos.xy, cascade);
        float sampleDepth = solidShadowMap.Sample(shadowCoord).r;
        distFinal += max(shadowPos.z - sampleDepth, 0.0);
        shadowFinal += step(shadowPos.z, sampleDepth);
        // sssDepth = max(shadowPos.z - sampleDepth, 0.0) * zRange;
    }

    return float2(shadowFinal, distFinal) / SHADOW_PCF_SAMPLES;
}


struct FragmentOutput {
    float4 shadow : SV_Target0;
    float4 sss : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput skyShadowSss(float2 pos : SV_Position) {
    FragmentOutput output;
    uint2 uv = uint2(pos);

    float depth = mainDepthTex[uv];
    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

    float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = project(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);
    float3 viewLocalDir = -normalize(localPos);

    float4 colorData = texAlbedoGB[uv];
    uint2 normalData = texNormalGB[uv];
    uint2 matLightData = texMatLightGB[uv];

    float4 specularData = unpackUnorm4x8ToFloat(matLightData.r);
    // float3 albedo = RgbToLinear(colorData.rgb);
    // float roughness = mat_roughness(specularData.r);
    // float f0_metal = mat_f0_metal(specularData.g);
    float sss = mat_sss(specularData.b);

    float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normalData.r).xyz * 2.0 - 1.0);
    float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normalData.g).xyz * 2.0 - 1.0);

    float4 lightData = unpackUnorm4x8ToFloat(matLightData.g);

    // Shadows
    float viewDist = length(viewPos);
    float geo_NoLm = 1.0 - abs(dot(geo_normal, scene[0].SkyLightLocalDir));
    float normal_bias = geo_NoLm * (viewDist * 0.006 + 0.06);
    float offset_bias = viewDist * 0.002;

    float3 shadowLocalPos = geo_normal * normal_bias + localPos;
    float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
    shadowViewPos.z += offset_bias;
    
    const float paddingBlocks = 0.05;
    int cascade = GetShadowProjection(shadowViewPos, paddingBlocks);

    output.shadow = 1.0;
    if (cascade >= 0) {
        float3 shadowPos = mul3(ap.celestial.projection[cascade], shadowViewPos).xyz * 0.5 + 0.5;

        output.shadow = SampleShadow(shadowPos, cascade);
    }

    // SSS
    shadowViewPos = mul3(ap.celestial.view, localPos);
    
    float blockRadius = sss * SSS_BlockRadius;
    cascade = GetShadowProjection(shadowViewPos, blockRadius);

    output.sss = float4(0.0, 0.0, 0.0, 1.0);
    if (cascade >= 0) {
        float3 shadowPos = mul3(ap.celestial.projection[cascade], shadowViewPos).xyz * 0.5 + 0.5;

        float dither;
        if (TAA_Enabled) {
            dither = InterleavedGradientNoiseTime(uv);
        }
        else {
            dither = InterleavedGradientNoise(uv);
        }

        float3 cascadeScale = GetProjectionScale(cascade);

        float bias_scale = sss * SSS_MaxDist * cascadeScale.z;
        float2 pixelRadius = blockRadius * cascadeScale.xy;
        float2 coverage_dist = SSS_PCF(shadowPos, cascade, pixelRadius, bias_scale, sss, dither);

        float absorb_depth = 1.0 * (coverage_dist.y / cascadeScale.z) + 0.1;
        float3 sss_color = normalize(RgbToLinear(1.0 - colorData.rgb) + 0.02);
        float3 lit = coverage_dist.x * exp(-(absorb_depth * sss_color + EPSILON));

        float tex_NoLm = max(dot(tex_normal, scene[0].SkyLightLocalDir), 0.0);
        output.sss.rgb = sss * (1.0 - tex_NoLm) * lit;
    }

    return output;
}
