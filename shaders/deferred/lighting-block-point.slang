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
groupshared uint sharedLightList[256];
groupshared Atomic<uint> depthMin, depthMax;
groupshared Atomic<uint> counter;

ConstantBuffer<SceneBuffer> scene;

[[vk::image_format("rgba16f")]]
RWTexture2D<float4> imgDiffuse;

[[vk::image_format("rgba16f")]]
RWTexture2D<float4> imgSpecular;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float> mainDepthTex;
SamplerCubeArrayShadow pointLightFiltered;


float sample_PointLightShadow(const in float3 sampleDir, const in float sampleDist, const in float lightRange, in float bias, const in uint index) {
    //if (sampleDist >= lightRange) return 0.0;

    float depth = (sampleDist - bias - ap.lights.nearPlane) / (ap.lights.farPlane - ap.lights.nearPlane);
    return pointLightFiltered.SampleCmp(float4(sampleDir, index), depth).r;
}


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
        depthMin = uint.maxValue;
        depthMax = uint.minValue;
        counter = 0;
    }

    GroupMemoryBarrierWithGroupSync();

    float depth = mainDepthTex[input.globalPos.xy];
    depthMin.min(uint(depth * uint.maxValue));
    depthMax.max(uint(depth * uint.maxValue));

    GroupMemoryBarrierWithGroupSync();

    // TODO: pre-compute bounds?

    if (input.groupIndex < ap.lights.count) {
        PointLight light = ap.lights[input.groupIndex];
        // TODO: collision test and set mask
        bool hit = light.block >= 0;

        if (hit) {
            uint index = counter.increment();
            sharedLightList[index] = input.groupIndex;
        }
    }

    GroupMemoryBarrierWithGroupSync();

    float2 texcoord = input.globalPos.xy / float2(ap.game.screenSize);
    if (TAA_Enabled) texcoord -= scene.taa_jitter;

    float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = unproject(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);

    uint normals_g = texNormalGB[input.globalPos.xy].g;
    float3 tex_normal = unpackUnorm4x8ToFloat(normals_g).xyz * 2.0 - 1.0;
    bool hasNormal = any(tex_normal > -1.0);
    if (hasNormal) tex_normal = normalize(tex_normal);

    float3 diffuse = imgDiffuse[input.globalPos.xy].rgb;
    float3 specular = imgSpecular[input.globalPos.xy].rgb;

    uint total = counter.load();
    for (uint i = 0; i < total; i++) {
        uint lightIndex = sharedLightList[i];
        PointLight light = ap.lights[lightIndex];
        BlockData block = ap.blocks[light.block];

        float3 lightOffset = light.position - localPos;
        uint lightRange = block.emission;

        float lightDist = length(lightOffset);
        float3 lightDir = lightOffset / lightDist;

        float lightAtt = 1.0 - saturate(lightDist / lightRange);
        if (lightAtt < EPSILON) continue;

        float3 lightColor = RgbToLinear(block.lightColor.rgb);
        float NoLm = max(dot(tex_normal, lightDir), 0.0);

        const float bias = 0.0;
        float shadow = sample_PointLightShadow(-lightDir, lightDist, lightRange, bias, lightIndex);

        diffuse += NoLm * lightAtt * shadow * BLOCK_LUX * lightColor;
        //specular += 0.0;
    }

    imgDiffuse[input.globalPos.xy] = float4(diffuse, 1.0);
    imgSpecular[input.globalPos.xy] = float4(specular, 1.0);
}
