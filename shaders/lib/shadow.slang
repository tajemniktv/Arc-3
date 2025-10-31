import aperture;
import buffers.scene;
import lib.common;
import lib.noise.hash;

extern static const uint Shadow_Resolution;
extern static const float Shadow_MaxPcfSize = 1.0;
extern static const float SHADOW_PENUMBRA_SCALE = 64.0;
extern static const int SHADOW_PCSS_SAMPLES = 5;
extern static const int SHADOW_PCF_SAMPLES = 5;
extern static const int SSS_PCF_SAMPLES = 3;

static const float GoldenAngle = PI * (3.0 - sqrt(5.0));
static const float PHI = (1.0 + sqrt(5.0)) / 2.0;

StructuredBuffer<SceneBuffer> scene;

Sampler2DArray solidShadowMap;
Sampler2DArrayShadow solidShadowMapFiltered;


float3 GetShadowProjectionScale(const in int cascade) {
    return float3(0.5, 0.5, -0.5) * float3(
        ap.celestial.projection[cascade][0].x,
        ap.celestial.projection[cascade][1].y,
        ap.celestial.projection[cascade][2].z);
}

int GetShadowProjection(const in float3 shadowViewPos, const in float padding) {
    int cascadeIndex = -1;
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

float SampleShadow(in float3 shadowPos, const in int cascade) {
    if (any(saturate(shadowPos) != shadowPos)) return 1.0;

    float3 shadowCoord = float3(shadowPos.xy, cascade);
    return solidShadowMapFiltered.SampleCmp(shadowCoord, shadowPos.z).r;
}

float ShadowBlockerDistance(const in float3 shadowPos, const in int cascade, const in float2 pixelRadius, const in float dither) {
    //float dither = GetShadowDither();
    //float zRange = GetShadowRange(cascade);
    float zRange = GetShadowProjectionScale(cascade).z;
    // TODO: why was this 1.0 instead of zero? bias issues?
    float bias = 0.0;//GetShadowBias(cascade);

    float angle = fract(dither) * (2.0 * PI);
    float s = sin(angle), c = cos(angle);
    float2x2 rotation = float2x2(
         c, s,
        -s, c);

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
        float hitDist = max((sampleShadowPos.z - texDepth) / zRange - bias, 0.0);

        avgDist += hitDist;
        blockers++;// += step(0.0, hitDist);
    }

    // return blockers > 0.0 ? avgDist / blockers : -1.0;
    return avgDist / blockers;
}

float SampleShadow_PCF(const in float3 shadowPos, const in int cascade, const in float2 pixelRadius, const in float dither) {
    if (any(saturate(shadowPos) != shadowPos)) return 1.0;

    //float dither = GetShadowDither();
    float bias = 0.0;//GetShadowBias(cascade);

    float angle = fract(dither) * (2.0 * PI);
    float s = sin(angle), c = cos(angle);
    float2x2 rotation = float2x2(
         c, s,
        -s, c);

    float shadowFinal = 0.0;
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;
        
        float2 pcfDiskOffset = r * float2(cos(theta), sin(theta));
        float2 pixelOffset = mul(rotation, pcfDiskOffset) * pixelRadius;
        float3 sampleShadowPos = shadowPos + float3(pixelOffset, -bias);

        shadowFinal += SampleShadow(sampleShadowPos, cascade);
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}

// float3 SampleShadowColor_PCF(const in float3 shadowPos, const in int shadowCascade, const in float2 pixelRadius, const in float dither) {
//     if (any(saturate(shadowPos) != shadowPos)) return 1.0;

//     //float dither = GetShadowDither();
//     float bias = GetShadowBias(shadowCascade);

//     float angle = fract(dither) * (2.0 * PI);
//     float s = sin(angle), c = cos(angle);
//     float2x2 rotation = float2x2(
//          c, s,
//         -s, c);

//     // const float pixelRadius = 2.0 / shadowMapResolution;

//     float3 shadowFinal = 0.0;
//     for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
//         float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
//         float theta = i * GoldenAngle + PHI;
        
//         float2 pcfDiskOffset = r * float2(cos(theta), sin(theta));
//         float2 pixelOffset = mul(rotation, pcfDiskOffset) * pixelRadius;
//         float3 sampleShadowPos = shadowPos + float3(pixelOffset, -bias);

//         shadowFinal += SampleShadowColor(sampleShadowPos, shadowCascade);
//     }

//     return shadowFinal / SHADOW_PCF_SAMPLES;
// }

float SampleShadow_PCSS(const in float3 shadowPos, const in int cascade, const in float dither) {
    float3 projectionScale = GetShadowProjectionScale(cascade);

    float2 maxPixelRadius = Shadow_MaxPcfSize * projectionScale.xy;
    float blockerDistance = ShadowBlockerDistance(shadowPos, cascade, maxPixelRadius, dither);

    const float shadowPixelSize = rcp(Shadow_Resolution);
    const float minShadowPixelRadius = 0.5 * shadowPixelSize;

    float2 pixelRadius = (blockerDistance / SHADOW_PENUMBRA_SCALE) * projectionScale.xy;
    pixelRadius = clamp(pixelRadius, float2(minShadowPixelRadius), maxPixelRadius);
    return SampleShadow_PCF(shadowPos, cascade, pixelRadius, dither);
}

// float3 SampleShadowColor_PCSS(const in float3 shadowPos, const in int shadowCascade) {
//     float2 maxPixelRadius = GetPixelRadius(Shadow_MaxPcfSize, shadowCascade);
//     float blockerDistance = ShadowBlockerDistance(shadowPos, shadowCascade, maxPixelRadius);

//     const float minShadowPixelRadius = 0.5 * shadowPixelSize;

//     float2 pixelRadius = GetPixelRadius(blockerDistance / SHADOW_PENUMBRA_SCALE, shadowCascade);
//     pixelRadius = clamp(pixelRadius, float2(minShadowPixelRadius), maxPixelRadius);
//     return SampleShadowColor_PCF(shadowPos, shadowCascade, pixelRadius);
// }

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
