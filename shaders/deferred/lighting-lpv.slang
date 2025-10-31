import aperture;
import buffers.scene;
import lib.common;

extern static const bool TAA_Enabled;
extern static const bool Lighting_GI_Enabled;
extern static const float Lighting_LPV_Range;
extern static const float Lighting_LPV_TemporalBlend;
extern static const float Lighting_LPV_Propagation;
extern static const float Lighting_LPV_MaxEnergy;

ConstantBuffer<SceneBuffer> scene;

static const uint LPV_GRID_RESOLUTION = 32u;
static const float3 LPV_GRID_SIZE = float3(LPV_GRID_RESOLUTION, LPV_GRID_RESOLUTION, LPV_GRID_RESOLUTION);

[[vk::image_format("rgba16f")]]
RWTexture3D<float4> imgLpvRadiance;

Sampler3D<float4> texLpvRadianceHistory;

Sampler2D<float3> texDiffuse;
Sampler2D<float4> texIndirectDiffuse;
Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float> mainDepthTex;

float2 worldToTexcoord(const in float3 worldPos, out float clipZ) {
    float3 viewPos = mul3(ap.camera.view, worldPos);
    float3 clipPos = project(ap.camera.projection, viewPos);
    clipZ = clipPos.z;
    float2 uv = clipPos.xy * 0.5 + 0.5;
    if (TAA_Enabled) uv += scene.taa_jitter;
    return uv;
}

float3 reconstructLocalPosition(const in float2 texcoord, const in float depth) {
    float3 clip = float3(texcoord, depth) * 2.0 - 1.0;
    float3 view = project(ap.camera.projectionInv, clip);
    return mul3(ap.camera.viewInv, view);
}

float3 sampleHistory(const in int3 coord) {
    if (any(coord < 0) || any(coord >= int3(LPV_GRID_RESOLUTION, LPV_GRID_RESOLUTION, LPV_GRID_RESOLUTION))) {
        return 0.0;
    }

    float3 uv = (float3(coord) + 0.5) / LPV_GRID_SIZE;
    return texLpvRadianceHistory.SampleLevel(uv, 0.0).rgb;
}

float3 propagateEnergy(const in float3 history, const in int3 coord) {
    float propagation = saturate(Lighting_LPV_Propagation);
    if (propagation <= 0.0) {
        return history;
    }

    static const int3 neighborOffsets[6] = {
        int3(1, 0, 0),
        int3(-1, 0, 0),
        int3(0, 1, 0),
        int3(0, -1, 0),
        int3(0, 0, 1),
        int3(0, 0, -1)
    };

    float3 accum = 0.0;
    float weight = 0.0;

    for (int i = 0; i < 6; ++i) {
        int3 neighborCoord = coord + neighborOffsets[i];
        if (any(neighborCoord < 0) || any(neighborCoord >= int3(LPV_GRID_RESOLUTION, LPV_GRID_RESOLUTION, LPV_GRID_RESOLUTION))) {
            continue;
        }

        float3 sample = sampleHistory(neighborCoord);
        accum += sample;
        weight += 1.0;
    }

    if (weight <= 0.0) {
        return history;
    }

    float3 average = accum / weight;
    return lerp(history, average, propagation);
}

struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(4, 4, 4)]
void injectLpvRadiance(ComputeInput input) {
    if (any(input.globalPos >= LPV_GRID_RESOLUTION)) {
        return;
    }

    float3 gridCoord = (float3(input.globalPos) + 0.5) / LPV_GRID_SIZE;
    float extent = Lighting_LPV_Range;
    float3 gridMin = ap.camera.position - extent;
    float3 worldPos = gridMin + gridCoord * (extent * 2.0);

    float clipZ;
    float2 texcoordJittered = worldToTexcoord(worldPos, clipZ);
    bool validInjection = false;
    float3 injection = 0.0;

    if (abs(clipZ) <= 1.0 && all(texcoordJittered == saturate(texcoordJittered))) {
        uint2 pixel = uint2(texcoordJittered * float2(ap.game.screenSize));
        if (all(pixel < ap.game.screenSize)) {
            float depth = mainDepthTex[pixel];
            if (depth < 1.0) {
                float2 texcoord = (float2(pixel) + 0.5) / float2(ap.game.screenSize);
                if (TAA_Enabled) texcoord -= scene.taa_jitter;

                float3 surfaceWorld = reconstructLocalPosition(texcoord, depth);
                float cellSize = max((extent * 2.0) / float(LPV_GRID_RESOLUTION), 0.01);
                float maxDistance = cellSize * 1.7320508;
                float distanceToSurface = length(surfaceWorld - worldPos);

                if (distanceToSurface <= maxDistance) {
                    float4 albedoSample = texAlbedoGB[pixel];
                    float3 albedo = RgbToLinear(albedoSample.rgb);
                    uint2 matData = texMatLightGB[pixel];
                    float4 lightData = unpackUnorm4x8ToFloat(matData.g);
                    float occlusion = lightData.b;
                    float3 diffuseLight = texDiffuse[pixel];
                    float3 giLight = Lighting_GI_Enabled ? texIndirectDiffuse[pixel].rgb : 0.0;
                    float falloff = saturate(1.0 - distanceToSurface / maxDistance);

                    injection = (diffuseLight + giLight) * albedo * occlusion * falloff;
                    validInjection = true;
                }
            }
        }
    }

    int3 coord = int3(input.globalPos);
    float3 history = texLpvRadianceHistory.SampleLevel(gridCoord, 0.0).rgb;
    history = propagateEnergy(history, coord);

    float3 result = history;
    if (validInjection) {
        float blend = saturate(Lighting_LPV_TemporalBlend);
        result = lerp(history, history + injection, blend);
    }

    result = min(result, Lighting_LPV_MaxEnergy);
    result = max(result, 0.0);

    imgLpvRadiance[input.globalPos] = float4(result, 1.0);
}
