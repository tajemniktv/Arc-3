import aperture;
import buffers.scene;
import lib.common;

extern static const float BLOCK_LUX = 200.0;
extern static const bool TAA_Enabled;

static const uint groupResX = 16;
static const uint groupResY = 16;

static const uint sharedBufferResX = groupResX+2;
static const uint sharedBufferResY = groupResY+2;
static const uint sharedBufferSize = sharedBufferResX*sharedBufferResY;
groupshared float sharedDepthBuffer[sharedBufferSize];
groupshared uint sharedLightList[256];
groupshared Atomic<float> depthMin, depthMax;
groupshared Atomic<uint> counter;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float> mainDepthTex;


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(16, 16, 1)]
void applyPointLights(ComputeInput input) {
    if (input.groupIndex == 0) {
        depthMin = 1.0;
        depthMax = 0.0;
        counter = 0;
    }

    GroupMemoryBarrierWithGroupSync();

    float depth = mainDepthTex[input.globalPos.xy];
    sharedDepthBuffer[input.groupIndex] = depth;

    depthMin.min(depth);
    depthMax.max(depth);

    GroupMemoryBarrierWithGroupSync();

    if (input.groupIndex < ap.lights.count) {
        PointLight light = ap.lights[input.groupIndex];
        // TODO: collision test and set mask
        bool hit = false;

        if (hit) {
            uint index = counter.increment();
            sharedLightList[index] = input.groupIndex;
        }
    }

    GroupMemoryBarrierWithGroupSync();

    uint total = counter.load();
    for (uint i = 0; i < total; i++) {
        uint lightIndex = sharedLightList[i];
        PointLight light = ap.lights[lightIndex];
        // TODO: sample light
    }
}
