import aperture;
import buffers.scene;
import lib.common;
import lib.sampling.depth;
import lib.hsv;

extern static const float BLOCK_LUX = 200.0;
extern static const int PointLight_MaxCount;
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


float GetLightAttenuation_Linear(const in float lightDist, const in float lightRange) {
    float lightDistF = lightDist / lightRange;
    lightDistF = 1.0 - saturate(lightDistF);
    return pow(lightDistF, 5);
}

float GetLightAttenuation_invSq(const in float lightDist, const in float lightRadius) {
    return 1.0 / ((lightDist*lightDist) + lightRadius);
}

float GetLightAttenuation(const in float lightDist, const in float lightRange, const in float lightRadius) {
    float linear = GetLightAttenuation_Linear(lightDist, lightRange);
    float invSq = GetLightAttenuation_invSq(max(lightDist-lightRadius, 0.0), lightRadius);

    float f = saturate(lightDist / lightRange);
    return lerp(invSq, linear, f);
}

float4 projectSphereView(float3 center, float radius, float P00, float P11) {
    float3 cr = center * radius;
    float czr2 = center.z * center.z - radius * radius;
    float2 v = sqrt(center.xy * center.xy + czr2);

    float minx = (v.x * center.x - cr.z) / (v.x * center.z + cr.x);
    float maxx = (v.x * center.x + cr.z) / (v.x * center.z - cr.x);

    float miny = (v.y * center.y - cr.z) / (v.y * center.z + cr.y);
    float maxy = (v.y * center.y + cr.z) / (v.y * center.z - cr.y);

    float4 aabb = float4(minx * P00, miny * P11, maxx * P00, maxy * P11);
    // clip space -> uv space
    aabb = aabb * float4(0.5f, -0.5f, 0.5f, -0.5f) + float4(0.5f);

    return aabb;
}

float3 unprojectCorner(const in float screenPosX, const in float screenPosY) {
    float3 ndcPos = float3(screenPosX, screenPosY, 1.0) * 2.0 - 1.0;
    return project(ap.camera.projectionInv, ndcPos);
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
        depthMinInt = uint.maxValue;
        depthMaxInt = uint.minValue;
        counter = 0;
    }

    GroupMemoryBarrierWithGroupSync();

    const float ap_camera_near = 0.05;
    float ap_camera_far = ap.world.renderDistance * 4.0;

    float depth = mainDepthTex[input.globalPos.xy];
    float depthL = linearizeDepth(depth * 2.0 - 1.0, ap_camera_near, ap_camera_far);
    float depthInt = depthL / ap_camera_far * uint.maxValue;
    depthMinInt.min(uint(floor(depthInt)));
    depthMaxInt.max(uint(ceil(depthInt)));

    GroupMemoryBarrierWithGroupSync();

    float depthMin = depthMinInt.load() / float(uint.maxValue) * ap_camera_far;
    float depthMax = depthMaxInt.load() / float(uint.maxValue) * ap_camera_far;

    if (input.groupIndex < PointLight_MaxCount) {
        PointLight light = ap.lights[input.groupIndex];

        if (light.block >= 0) {
            uint lightRange = ap.blocks[light.block].emission + 0.5;

            // compute view-space position and collision test
            float3 lightViewPos = mul3(ap.camera.view, light.position);
            bool hit = true;

            if (-lightViewPos.z + lightRange < depthMin) hit = false;
            if (-lightViewPos.z - lightRange > depthMax) hit = false;

            // TODO: test X/Y
            uint2 groupPos = input.groupPos.xy * WorkgroupSize().xy;
            float2 groupPosMin = groupPos / float2(ap.game.screenSize);
            float2 groupPosMax = (groupPos + WorkgroupSize().xy) / float2(ap.game.screenSize);
            
            float3 c1 = unprojectCorner(groupPosMin.x, groupPosMin.y);
            float3 c2 = unprojectCorner(groupPosMax.x, groupPosMin.y);
            float3 c3 = unprojectCorner(groupPosMin.x, groupPosMax.y);
            float3 c4 = unprojectCorner(groupPosMax.x, groupPosMax.y);

            float3 clipDown  = normalize(cross(c2, c1));
            float3 clipRight = normalize(cross(c4, c2));
            float3 clipUp    = normalize(cross(c3, c4));
            float3 clipLeft  = normalize(cross(c1, c3));
            
            if (dot(clipDown,  lightViewPos) > lightRange) hit = false;
            if (dot(clipRight, lightViewPos) > lightRange) hit = false;
            if (dot(clipUp,    lightViewPos) > lightRange) hit = false;
            if (dot(clipLeft,  lightViewPos) > lightRange) hit = false;

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
    float3 viewPos = project(ap.camera.projectionInv, clipPos);
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
    // float hue = lerp(0.75, 0.0, total / 256.0);
    // specular = HsvToRgb(float3(hue, 1.0, 10.0));

    for (uint i = 0; i < total; i++) {
        uint lightIndex = sharedLightList[i];
        PointLight light = ap.lights[lightIndex];
        BlockData block = ap.blocks[light.block];

        float3 lightOffset = light.position - localSamplePos;
        uint lightRange = block.emission;

        float lightDist = length(lightOffset);
        float3 lightDir = lightOffset / lightDist;

        const float lightRadius = 0.5;
        float lightAtt = GetLightAttenuation(lightDist, lightRange, lightRadius);
        if (lightAtt < EPSILON) continue;

        float3 lightColor = RgbToLinear(block.lightColor.rgb);
        lightColor *= saturate(lightRange / 15.0);
        float NoLm = max(dot(tex_normal, lightDir), 0.0);

        float shadowDepth = unmix(ap.lights.nearPlane, ap.lights.farPlane, lightDist - offsetBias);
        float shadow = pointLightFiltered.SampleCmp(float4(-lightDir, lightIndex), shadowDepth).r;

        diffuse += NoLm * lightAtt * shadow * BLOCK_LUX * lightColor;
        //specular += 0.0;
    }

    imgDiffuse[input.globalPos.xy] = float4(diffuse, 1.0);
    imgSpecular[input.globalPos.xy] = float4(specular, 1.0);
}
