import aperture;
import lib.common;

extern static const uint SHADOW_CASCADE_COUNT = 4;

Sampler2DArray solidShadowMap;
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

float SampleShadow(in float3 shadowPos, const in int shadowCascade, out float sssDepth) {
    if (any(saturate(shadowPos) != shadowPos)) return 1.0;

    float zRange = -ap.celestial.projectionInv[shadowCascade]._33;
    float3 shadowCoord = float3(shadowPos.xy, shadowCascade);

    float sampleDepth = solidShadowMap.Sample(shadowCoord).r;
    sssDepth = max(shadowPos.z - sampleDepth, 0.0) * zRange;

    const float bias = 0.02 / zRange;
    return solidShadowMapFiltered.SampleCmp(shadowCoord, shadowPos.z - bias).r;
}
