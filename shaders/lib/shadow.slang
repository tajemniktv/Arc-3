import aperture;
import buffers.scene;
import lib.common;
import lib.noise.hash;

extern static const uint Shadow_Resolution;
extern static const float Shadow_MaxPcfSize = 0.6;
extern static const float SHADOW_PENUMBRA_SCALE = 64.0;
extern static const int SHADOW_PCSS_SAMPLES = 5;
extern static const int SHADOW_PCF_SAMPLES = 5;

extern static const int SSS_PCF_SAMPLES = 3;
extern static const float SSS_BlockRadius = 1.4;
extern static const float SSS_MaxDist = 6.0;

static const float GoldenAngle = PI * (3.0 - sqrt(5.0));
static const float PHI = (1.0 + sqrt(5.0)) / 2.0;

StructuredBuffer<SceneBuffer> scene;

Sampler2DArray<float> shadowMap;
Sampler2DArray<float> solidShadowMap;
Sampler2DArrayShadow solidShadowMapFiltered;
Sampler2DArray<half3> texShadowColor;


float3 GetShadowProjectionScale(const in int cascade) {
    return float3(0.5, 0.5, -0.5) * float3(
        ap.celestial.projection[cascade][0].x,
        ap.celestial.projection[cascade][1].y,
        ap.celestial.projection[cascade][2].z);
}

int GetShadowProjection(const in float3 shadowViewPos, const in float padding) {
    int cascadeIndex = -1;
    [ForceUnroll]
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        if (all(clamp(shadowViewPos.xy, scene[0].shadowViewMin[i] + padding, scene[0].shadowViewMax[i] - padding) == shadowViewPos.xy)) {
            cascadeIndex = i;
            break;
        }
    }

    return cascadeIndex;
}

float2 GetPixelRadius(const in float blockRadius, const in int cascade) {
    return blockRadius * GetShadowProjectionScale(cascade).xy;
}

float2x2 GetSampleRotation(const in float dither) {
    float angle = dither * (2.0*PI);
    float s = sin(angle);
    float c = cos(angle);

    return float2x2(
         c, s,
        -s, c);
}

float SampleShadow(in float3 shadowPos, const in int cascade) {
    float3 shadowCoord = float3(shadowPos.xy, cascade);
    return solidShadowMapFiltered.SampleCmp(shadowCoord, shadowPos.z).r;
}

float3 SampleShadowColor(in float3 shadowPos, const in int cascade) {
    float3 shadowCoord = float3(shadowPos.xy, cascade);
    float depthOpaque = solidShadowMap.Sample(shadowCoord);

    float3 shadow;
    if (shadowPos.z > depthOpaque) shadow = 0.0;
    else {
        float depthTrans = shadowMap.Sample(shadowCoord);

        if (shadowPos.z + EPSILON <= depthTrans) shadow = 1.0;
        else {
            shadow = texShadowColor.Sample(shadowCoord);
        }
    }

    return shadow;
}

float ShadowBlockerDistance(const in float3 shadowPos, const in int cascade, const in float2 pixelRadius, const in float zRange, const in float dither) {
    float2x2 rotation = GetSampleRotation(fract(dither + 0.681));

    float blockers = 0.0;
    float avgDist = 0.0;
    for (int i = 0; i < SHADOW_PCSS_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCSS_SAMPLES);
        float theta = i * GoldenAngle + PHI;

        float2 diskOffset = r * float2(cos(theta), sin(theta));
        float2 pixelOffset = mul(rotation, diskOffset) * pixelRadius;

        float3 sampleShadowPos = shadowPos;
        sampleShadowPos.xy += pixelOffset;

        float texDepth = solidShadowMap.Sample(float3(sampleShadowPos.xy, cascade)).r;
        float hitDist = max((sampleShadowPos.z - texDepth) / zRange, 0.0);

        avgDist += hitDist;
        blockers++;// += step(0.0, hitDist);
    }

    // return blockers > 0.0 ? avgDist / blockers : -1.0;
    return avgDist / blockers;
}

float SampleShadow_PCF(const in float3 shadowPos, const in int cascade, const in float2 pixelRadius, const in float dither) {
    float2x2 rotation = GetSampleRotation(fract(dither + 0.183));

    float shadowFinal = 0.0;
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;
        
        float2 pcfDiskOffset = r * float2(cos(theta), sin(theta));
        float2 pixelOffset = mul(rotation, pcfDiskOffset) * pixelRadius;
        float3 sampleShadowPos = shadowPos + float3(pixelOffset, 0.0);

        shadowFinal += SampleShadow(sampleShadowPos, cascade);
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}

float3 SampleShadowColor_PCF(const in float3 shadowPos, const in int cascade, const in float2 pixelRadius, const in float dither) {
    float2x2 rotation = GetSampleRotation(fract(dither + 0.183));

    float3 shadowFinal = 0.0;
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;
        
        float2 pcfDiskOffset = r * float2(cos(theta), sin(theta));
        float2 pixelOffset = mul(rotation, pcfDiskOffset) * pixelRadius;
        float3 sampleShadowPos = shadowPos + float3(pixelOffset, 0.0);

        shadowFinal += SampleShadowColor(sampleShadowPos, cascade);
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}

float SampleShadow_PCSS(const in float3 shadowPos, const in int cascade, const in float dither) {
    float3 projectionScale = GetShadowProjectionScale(cascade);

    float2 maxPixelRadius = Shadow_MaxPcfSize * projectionScale.xy;
    float blockerDistance = ShadowBlockerDistance(shadowPos, cascade, maxPixelRadius, projectionScale.z, dither);

    const float shadowPixelSize = rcp(Shadow_Resolution);
    const float minShadowPixelRadius = 0.5 * shadowPixelSize;

    float2 pixelRadius = (blockerDistance / SHADOW_PENUMBRA_SCALE) * projectionScale.xy;
    pixelRadius = clamp(pixelRadius, float2(minShadowPixelRadius), maxPixelRadius);
    return SampleShadow_PCF(shadowPos, cascade, pixelRadius, dither);
}

float3 SampleShadowColor_PCSS(const in float3 shadowPos, const in int cascade, const in float dither) {
    float3 projectionScale = GetShadowProjectionScale(cascade);

    float2 maxPixelRadius = Shadow_MaxPcfSize * projectionScale.xy;
    float blockerDistance = ShadowBlockerDistance(shadowPos, cascade, maxPixelRadius, projectionScale.z, dither);

    const float shadowPixelSize = rcp(Shadow_Resolution);
    const float minShadowPixelRadius = 0.5 * shadowPixelSize;

    float2 pixelRadius = (blockerDistance / SHADOW_PENUMBRA_SCALE) * projectionScale.xy;
    pixelRadius = clamp(pixelRadius, float2(minShadowPixelRadius), maxPixelRadius);
    return SampleShadowColor_PCF(shadowPos, cascade, pixelRadius, dither);
}

// [coverage, distance]
float2 SSS_PCF(const in float3 shadowPos, const in int cascade, const in float2 pixelRadius, const in float bias_scale, const in float sss, const in float dither) {
    float2x2 rotation = GetSampleRotation(fract(dither));
    float seed_pos = hash13(shadowPos * 999.0);

    float shadowFinal = 0.0;
    float distFinal = 0.0;
    for (int i = 0; i < SSS_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SSS_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;

        float sample_dither = sss * hash13(float3(seed_pos * 999.0, i, ap.timing.frameCounter));
        float sample_bias = bias_scale * pow3(sample_dither);
        
        float2 pcfDiskOffset = r * float2(cos(theta), sin(theta));
        float2 pixelOffset = mul(rotation, pcfDiskOffset) * pixelRadius;
        float3 sampleShadowPos = shadowPos + float3(pixelOffset, sample_bias);

        float3 shadowCoord = float3(sampleShadowPos.xy, cascade);
        float sampleDepth = solidShadowMap.Sample(shadowCoord).r;
        distFinal += max(shadowPos.z - sampleDepth, 0.0);
        shadowFinal += step(shadowPos.z, sampleDepth);
    }

    return float2(shadowFinal, distFinal) / SSS_PCF_SAMPLES;
}
