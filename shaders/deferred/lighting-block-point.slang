import aperture;
import buffers.scene;
import lib.common;
import lib.material.pbr;
import lib.light.brdf;
import lib.light.fresnel;
import lib.sampling.depth;
import lib.hsv;

extern static const float BLOCK_LUX;
extern static const int PointLight_MaxCount;
extern static const bool TAA_Enabled;
extern static const bool DEBUG_LIGHT_TILES;

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

[[vk::image_format("rgba8")]]
RWTexture2D<float4> imgDebug;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<float> mainDepthTex;
SamplerCubeArrayShadow pointLightFiltered;


// float4 projectSphereView(float3 center, float radius, float P00, float P11) {
//     float3 cr = center * radius;
//     float czr2 = center.z * center.z - radius * radius;
//     float2 v = sqrt(center.xy * center.xy + czr2);

//     float minx = (v.x * center.x - cr.z) / (v.x * center.z + cr.x);
//     float maxx = (v.x * center.x + cr.z) / (v.x * center.z - cr.x);

//     float miny = (v.y * center.y - cr.z) / (v.y * center.z + cr.y);
//     float maxy = (v.y * center.y + cr.z) / (v.y * center.z - cr.y);

//     float4 aabb = float4(minx * P00, miny * P11, maxx * P00, maxy * P11);
//     // clip space -> uv space
//     aabb = aabb * float4(0.5f, -0.5f, 0.5f, -0.5f) + float4(0.5f);

//     return aabb;
// }

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
            float lightRange = ap.blocks[light.block].emission + 0.5;

            // compute view-space position and collision test
            float3 lightViewPos = mul3(ap.camera.view, light.position);
            bool hit = true;

            if (-lightViewPos.z + lightRange < depthMin) hit = false;
            if (-lightViewPos.z - lightRange > depthMax) hit = false;

            // test X/Y
            uint2 groupPos = input.groupPos.xy * WorkgroupSize().xy;
            float2 groupPosMin = groupPos / float2(ap.game.screenSize);
            float2 groupPosMax = (groupPos + WorkgroupSize().xy) / float2(ap.game.screenSize);
            
            // Frustum planes from tile corners
            float3 c1 = unprojectCorner(groupPosMin.x, groupPosMin.y);
            float3 c2 = unprojectCorner(groupPosMax.x, groupPosMin.y);
            float3 c3 = unprojectCorner(groupPosMin.x, groupPosMax.y);
            float3 c4 = unprojectCorner(groupPosMax.x, groupPosMax.y);

			// 4 plane normals from corner cross products
            float3 clipDown  = normalize(cross(c2, c1));
            float3 clipRight = normalize(cross(c4, c2));
            float3 clipUp    = normalize(cross(c3, c4));
            float3 clipLeft  = normalize(cross(c1, c3));
            
            // is light sphere outside of any plane
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

    float3 diffuse = 0.0;
    float3 specular = 0.0;

    float4 colorData = texAlbedoGB[input.globalPos.xy];
    uint2 normal_data = texNormalGB[input.globalPos.xy];
    uint2 mat_light_data = texMatLightGB[input.globalPos.xy];

    float2 texcoord = (input.globalPos.xy + 0.5) / float2(ap.game.screenSize);
    if (TAA_Enabled) texcoord -= scene.taa_jitter;

    float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = project(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);

    float3 viewDir = -normalize(localPos);

    float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normal_data.r).xyz * 2.0 - 1.0);
    float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normal_data.g).xyz * 2.0 - 1.0);
    float4 specular_data = unpackUnorm4x8ToFloat(mat_light_data.r);

    float roughness = mat_roughness(specular_data.r);
    float f0_metal = mat_f0_metal(specular_data.g);

    float3 albedo = RgbToLinear(colorData.rgb);
    float roughL = roughness * roughness;

    const float offsetBias = 0.06;
    const float normalBias = 0.12;
    float3 localSamplePos = normalBias * geo_normal + localPos;

    float NoVm = max(dot(tex_normal, viewDir), 0.0);
    float3 f0 = f0_metal < 0.9 ? f0_metal : albedo;

    uint total = counter.load();

    if (DEBUG_LIGHT_TILES) {
        float hue = lerp(0.65, 0.0, total / 256.0);
        float3 color = HsvToRgb(float3(hue, 1.0, 1.0));
        imgDebug[input.globalPos.xy] = float4(color, 1.0);
    }

    for (uint i = 0; i < total; i++) {
        uint lightIndex = sharedLightList[i];
        PointLight light = ap.lights[lightIndex];
        BlockData block = ap.blocks[light.block];

        float3 lightOffset = light.position - localSamplePos;
        uint lightRange = block.emission;

        float lightDist = length(lightOffset);
        float3 lightDir = lightOffset / lightDist;

		// Light Attenuation
        const float lightRadius = 0.5;
        float lightAtt = GetLightAttenuation(lightDist, lightRange, lightRadius);
        if (lightAtt < EPSILON) continue;

        float3 lightColor = RgbToLinear(block.lightColor.rgb);
        lightColor *= saturate(lightRange / 15.0) * BLOCK_LUX;

        float shadowDepth = unmix(ap.lights.nearPlane, ap.lights.farPlane, lightDist - offsetBias);
        float shadow = pointLightFiltered.SampleCmp(float4(-lightDir, lightIndex), shadowDepth).r;

        float3 H = normalize(lightDir + viewDir);
        float NoLm = max(dot(tex_normal, lightDir), 0.0);
        float NoHm = max(dot(tex_normal, H), 0.0);
        float LoHm = max(dot(lightDir, H), 0.0);
        float VoHm = max(dot(viewDir, H), 0.0);

        shadow *= NoLm * lightAtt;

        float D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);
        diffuse += shadow * D * lightColor;

        //float3 F_VoH = material_fresnel(albedo, f0_metal, roughL, VoHm);
        float3 F_VoH = F_schlickRough(VoHm, f0, roughL);
        
        float3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F_VoH, roughL);
        specular += shadow * S * lightColor;
    }

    if (mat_isMetal(f0_metal)) diffuse *= roughness;

    diffuse += imgDiffuse[input.globalPos.xy].rgb;
    specular += imgSpecular[input.globalPos.xy].rgb;

    imgDiffuse[input.globalPos.xy] = float4(diffuse, 1.0);
    imgSpecular[input.globalPos.xy] = float4(specular, 1.0);
}
