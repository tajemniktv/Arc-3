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
groupshared Atomic<uint> depthMinInt, depthMaxInt;
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
        depthMinInt = uint.maxValue;
        depthMaxInt = uint.minValue;
        counter = 0;
    }

    GroupMemoryBarrierWithGroupSync();

    float depth = mainDepthTex[input.globalPos.xy];
    uint depthInt = uint(depth * uint.maxValue);
    // TODO: linearize depth?
    depthMinInt.min(depthInt);
    depthMaxInt.max(depthInt);

    GroupMemoryBarrierWithGroupSync();

    float depthMin = depthMinInt.load() / float(uint.maxValue);
    float depthMax = depthMaxInt.load() / float(uint.maxValue);

    if (input.groupIndex < ap.lights.count) {
        PointLight light = ap.lights[input.groupIndex];

        if (light.block >= 0) {
            uint lightRange = ap.blocks[light.block].emission;

            // compute screen-space bounds
            float3 lightViewPos = mul3(ap.camera.view, light.position);
            //float3 lightClipPos = unproject(ap.camera.projection, lightViewPos);

            float3 lightViewPosMin = lightViewPos - float2(lightRange, -lightRange).xxy;
            float3 lightClipPosMin = unproject(ap.camera.projection, lightViewPosMin);
            lightClipPosMin = lightClipPosMin * 0.5 + 0.5;

            float3 lightViewPosMax = lightViewPos + float2(lightRange, -lightRange).xxy;
            float3 lightClipPosMax = unproject(ap.camera.projection, lightViewPosMax);
            lightClipPosMax = lightClipPosMax * 0.5 + 0.5;
            
            // TODO: collision test and set mask
            bool hit = true;
            // if (lightClipPosMax.z < depthMin) hit = false;
            // if (lightClipPosMin.z > depthMax) hit = false;

            if (hit) {
                uint index = counter.increment();
                sharedLightList[index] = input.groupIndex;
            }
        }
    }

    GroupMemoryBarrierWithGroupSync();

    float2 texcoord = input.globalPos.xy / float2(ap.game.screenSize);
    if (TAA_Enabled) texcoord -= scene.taa_jitter;

    float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = unproject(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);

    uint2 normals = texNormalGB[input.globalPos.xy];
    float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
    float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);

    // bool hasNormal = any(tex_normal > -1.0);
    // if (hasNormal) tex_normal = normalize(tex_normal);

    const float offsetBias = 0.02;
    const float normalBias = 0.16;
    float3 localSamplePos = normalBias * geo_normal + localPos;

    float3 diffuse = imgDiffuse[input.globalPos.xy].rgb;
    float3 specular = imgSpecular[input.globalPos.xy].rgb;

    uint total = counter.load();
    for (uint i = 0; i < total; i++) {
        uint lightIndex = sharedLightList[i];
        PointLight light = ap.lights[lightIndex];
        BlockData block = ap.blocks[light.block];

        float3 lightOffset = light.position - localSamplePos;
        uint lightRange = block.emission;

        float lightDist = length(lightOffset);
        float3 lightDir = lightOffset / lightDist;

        float lightAtt = 1.0 - saturate(lightDist / lightRange);
        if (lightAtt < EPSILON) continue;

        float3 lightColor = RgbToLinear(block.lightColor.rgb);
        float NoLm = max(dot(tex_normal, lightDir), 0.0);

        float shadowDepth = unmix(ap.lights.nearPlane, ap.lights.farPlane, lightDist - offsetBias);
        float shadow = pointLightFiltered.SampleCmp(float4(-lightDir, lightIndex), shadowDepth).r;

        diffuse += NoLm * lightAtt * shadow * BLOCK_LUX * lightColor;
        //specular += 0.0;
    }

    imgDiffuse[input.globalPos.xy] = float4(diffuse, 1.0);
    imgSpecular[input.globalPos.xy] = float4(specular, 1.0);
}
