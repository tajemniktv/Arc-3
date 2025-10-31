import aperture;
import buffers.scene;
import lib.common;
import lib.noise.hash;

extern static const bool TAA_Enabled;
extern static const int Lighting_GI_SampleCount;
extern static const float Lighting_GI_Radius;
extern static const float Lighting_GI_Strength;
extern static const float Lighting_GI_TemporalResponse;
extern static const float Lighting_GI_HistoryMax;

ConstantBuffer<SceneBuffer> scene;

static const uint groupResX = 16;
static const uint groupResY = 16;

[[vk::image_format("rgba16f")]]
RWTexture2D<float4> imgIndirectDiffuse;

Sampler2D<float4> texIndirectHistory;
Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float3> texDiffuse;
Sampler2D<float> mainDepthTex;

float3 decodeNormal(const in uint packed) {
    return normalize(unpackUnorm4x8ToFloat(packed).xyz * 2.0 - 1.0);
}

float2 pixelToTexcoord(const in uint2 pixel) {
    float2 texcoord = (pixel + 0.5) / float2(ap.game.screenSize);
    if (TAA_Enabled) texcoord -= scene.taa_jitter;
    return texcoord;
}

float3 reconstructLocalPosition(const in float2 texcoord, const in float depth) {
    float3 clip = float3(texcoord, depth) * 2.0 - 1.0;
    float3 view = project(ap.camera.projectionInv, clip);
    return mul3(ap.camera.viewInv, view);
}

float2 projectToTexcoord(const in float3 localPos, out float clipZ) {
    float3 viewPos = mul3(ap.camera.view, localPos);
    float3 clip = project(ap.camera.projection, viewPos);
    clipZ = clip.z;
    float2 uv = clip.xy * 0.5 + 0.5;
    if (TAA_Enabled) uv += scene.taa_jitter;
    return uv;
}

float3 createTangent(const in float3 normal) {
    float3 up = abs(normal.y) < 0.999 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    float3 tangent = normalize(cross(up, normal));
    return tangent;
}

float3 cosineSampleHemisphere(const in float2 xi) {
    float phi = xi.x * (2.0 * PI);
    float cosTheta = sqrt(saturate(1.0 - xi.y));
    float sinTheta = sqrt(saturate(xi.y));
    float2 sincosPhi = float2(cos(phi), sin(phi));
    return float3(sincosPhi.x * sinTheta, sincosPhi.y * sinTheta, cosTheta);
}

struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(groupResX, groupResY, 1)]
void buildIndirectDiffuse(ComputeInput input) {
    if (any(input.globalPos.xy >= ap.game.screenSize)) return;

    uint2 pixel = input.globalPos.xy;
    float depth = mainDepthTex[pixel];
    if (depth == 1.0) {
        imgIndirectDiffuse[pixel] = 0.0;
        return;
    }

    if (Lighting_GI_SampleCount <= 0 || Lighting_GI_Radius <= 0.0) {
        imgIndirectDiffuse[pixel] = 0.0;
        return;
    }

    float2 texcoordJittered = (pixel + 0.5) / float2(ap.game.screenSize);
    float2 texcoord = texcoordJittered;
    if (TAA_Enabled) texcoord -= scene.taa_jitter;

    float3 localPos = reconstructLocalPosition(texcoord, depth);

    uint2 normalData = texNormalGB[pixel];
    float3 receiverNormal = decodeNormal(normalData.g);

    float4 lightData = unpackUnorm4x8ToFloat(texMatLightGB[pixel].g);
    float occlusion = lightData.b;

    float angle = hash11(dot(float2(pixel), float2(1.0, 3.1)) + scene.frame * 0.25); // ap.time.framess not working?
    float s = sin(angle * (2.0 * PI));
    float c = cos(angle * (2.0 * PI));

    float3 tangent = createTangent(receiverNormal);
    float3 bitangent = normalize(cross(receiverNormal, tangent));
    float3 rotatedTangent = tangent * c + bitangent * s;
    float3 rotatedBitangent = normalize(cross(receiverNormal, rotatedTangent));

    float3 indirectAccum = 0.0;
    float weightAccum = 0.0;
    uint validSamples = 0u;

    float frame = scene.frame;

    static const float minSampleDistance = 0.1;

    for (int sampleIndex = 0; sampleIndex < Lighting_GI_SampleCount; ++sampleIndex) {
        float3 rand = hash33(float3(float(pixel.x), float(pixel.y), frame + sampleIndex * 1.37));

        float3 hemi = cosineSampleHemisphere(rand.xy);
        float3 sampleDir = normalize(rotatedTangent * hemi.x + rotatedBitangent * hemi.y + receiverNormal * hemi.z);

        float NoL = max(dot(receiverNormal, sampleDir), 0.0);
        if (NoL <= 0.0) continue;

        float sampleDistance = Lighting_GI_Radius * rand.z;
        sampleDistance = max(sampleDistance, minSampleDistance);

        float3 sampleLocal = localPos + sampleDir * sampleDistance;
        float clipZ;
        float2 sampleUv = projectToTexcoord(sampleLocal, clipZ);
        if (clipZ <= -1.0 || clipZ >= 1.0) continue;
        if (any(sampleUv < 0.0) || any(sampleUv > 1.0)) continue;

        uint2 samplePixel = uint2(sampleUv * float2(ap.game.screenSize));
        if (any(samplePixel >= ap.game.screenSize)) continue;

        float sampleDepth = mainDepthTex[samplePixel];
        if (sampleDepth == 1.0) continue;

        float2 sampleTexcoord = pixelToTexcoord(samplePixel);
        float3 sampleLocalPos = reconstructLocalPosition(sampleTexcoord, sampleDepth);

        float3 delta = sampleLocalPos - localPos;
        float distActual = length(delta);
        if (distActual < minSampleDistance) continue;
        if (distActual > Lighting_GI_Radius) continue;

        float distanceError = abs(distActual - sampleDistance) / max(sampleDistance, 0.001);
        if (distanceError > 0.35) continue;

        float3 direction = delta / distActual;
        float NdotL = max(dot(receiverNormal, direction), 0.0);
        if (NdotL <= 0.0) continue;

        uint2 sampleNormalData = texNormalGB[samplePixel];
        float3 sampleNormal = decodeNormal(sampleNormalData.g);
        float sampleNdotL = max(dot(sampleNormal, -direction), 0.0);
        if (sampleNdotL <= 0.0) continue;

        float4 sampleLight = unpackUnorm4x8ToFloat(texMatLightGB[samplePixel].g);
        float sampleOcclusion = sampleLight.b;

        float4 sampleAlbedo = texAlbedoGB[samplePixel];
        float3 sampleAlbedoLin = RgbToLinear(sampleAlbedo.rgb);
        float3 sampleIrradiance = texDiffuse[samplePixel];
        float3 bounceRadiance = sampleIrradiance * sampleAlbedoLin * sampleOcclusion;

        float falloff = saturate(1.0 - distActual / Lighting_GI_Radius);
        float weight = NdotL * sampleNdotL * falloff;
        if (weight <= 0.0) continue;

        indirectAccum += bounceRadiance * weight;
        weightAccum += weight;
        validSamples++;
    }

    float3 indirectIrradiance = 0.0;
    if (weightAccum > EPSILON) {
        indirectIrradiance = indirectAccum / weightAccum;
    }

    indirectIrradiance *= occlusion;
    indirectIrradiance *= Lighting_GI_Strength;

    float3 historyColor = 0.0;
    float historyCount = 0.0;
    bool historyValid = false;

    if (Lighting_GI_TemporalResponse > 0.0) {
        float3 localPrev = localPos + (ap.camera.position - ap.temporal.position);
        float3 viewPrev = mul3(ap.temporal.view, localPrev);
        float3 clipPrev = project(ap.temporal.projection, viewPrev);
        float2 uvPrev = clipPrev.xy * 0.5 + 0.5;

        if (all(saturate(uvPrev) == uvPrev) && abs(clipPrev.z) <= 1.0) {
            float4 history = texIndirectHistory.SampleLevel(uvPrev, 0.0);
            historyColor = history.rgb;
            historyCount = history.a;
            historyValid = true;
        }
    }

    float3 filtered = indirectIrradiance;
    float newHistory = validSamples > 0 ? 1.0 : 0.0;

    if (Lighting_GI_TemporalResponse > 0.0 && historyValid) {
        float historyWeight = historyCount * Lighting_GI_TemporalResponse;
        float totalWeight = historyWeight + (validSamples > 0 ? 1.0 : 0.0);

        if (totalWeight > 0.0) {
            filtered = (historyColor * historyWeight + indirectIrradiance * (validSamples > 0 ? 1.0 : 0.0)) / totalWeight;
            newHistory = min(totalWeight, Lighting_GI_HistoryMax);
        }
        else {
            filtered = historyColor;
            newHistory = historyCount;
        }
    }
    else if (validSamples == 0 && historyValid) {
        filtered = historyColor;
        newHistory = historyCount;
    }

    if (validSamples == 0 && !historyValid) {
        filtered = 0.0;
        newHistory = 0.0;
    }

    imgIndirectDiffuse[pixel] = float4(filtered, newHistory);
}
