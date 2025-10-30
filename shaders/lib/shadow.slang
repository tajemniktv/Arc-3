import aperture;
import buffers.scene;
import lib.common;

StructuredBuffer<SceneBuffer> scene;

Sampler2DArray solidShadowMap;
Sampler2DArrayShadow solidShadowMapFiltered;


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

float SampleShadow(in float3 shadowPos, const in int cascade) {
    if (any(saturate(shadowPos) != shadowPos)) return 1.0;

    // float zRange = -0.5 * ap.celestial.projectionInv[cascade]._33;
    float3 shadowCoord = float3(shadowPos.xy, cascade);

    // float sampleDepth = solidShadowMap.Sample(shadowCoord).r;
    // sssDepth = max(shadowPos.z - sampleDepth, 0.0) * zRange;

    return solidShadowMapFiltered.SampleCmp(shadowCoord, shadowPos.z).r;
}
