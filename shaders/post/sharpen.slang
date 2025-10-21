import aperture;
import lib.common;

// https://github.com/GPUOpen-Effects/FidelityFX-CAS/blob/master/ffx-cas/ffx_cas.h#L423

[[vk::image_format("rgba16f")]]
RWTexture2D<float4> imgFinal;

Sampler2D<float4> texFinal;

extern static const float sharpness = 0.5;
static const uint groupResX = 16;
static const uint groupResY = 8;

static const uint sharedBufferResX = groupResX+2;
static const uint sharedBufferResY = groupResY+2;
static const uint sharedBufferSize = sharedBufferResX*sharedBufferResY;
groupshared float3 sharedBuffer[sharedBufferSize];


float AMin3F1(float x, float y, float z) {
    return min(x, min(y, z));
}

float minOf(float x, float y, float z) {
    return min(x, min(y, z));
}

float AMax3F1(float x, float y, float z) {
    return max(x, max(y, z));
}

// int MORTON_MASKS[5] = int[](0x55555555, 0x33333333, 0x0F0F0F0F, 0x00FF00FF, 0x0000FFFF);

// int xy2z(const in int2 U) {
//     int2 I = int2(U);
//     int n = 8;
//     for (int i = 3; i >= 0; i--) {
//         I =  (I | (I << n)) & MORTON_MASKS[i];
//         n /= 2;
//     }
//     return I.x | (I.y << 1);
// }

// int2 z2xy(const in int z) {
//     int n = 1;
//     int2 I = int2(z, z >> 1) & MORTON_MASKS[0];
//     for (int i=1; i<=4; i++) {
//         I = (I | (I >>  n)) & MORTON_MASKS[i];
//         n *= 2;
//     }
//     return I;
// }

uint2 getSharedUV(const in uint z) {
    // return z2xy(uv);
    return uint2(
        z % sharedBufferResX,
        uint(z / float(sharedBufferResX))
    );
}

int getSharedIndex(const in int2 uv) {
    // return xy2z(uv);
    return uv.y * sharedBufferResX + uv.x;
}

public void barrier() {
    __target_switch {
        case glsl: __intrinsic_asm "barrier()";
    }
}

struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(groupResX, groupResY, 1)]
void sharpen(ComputeInput input) {
    uint i_base = input.groupIndex * 2u;

    if (i_base < sharedBufferSize) {
        uint2 uv_base = input.groupPos.xy * uint2(groupResX, groupResY) - 1u;

        for (uint i = 0u; i < 2u; i++) {
            uint i_shared = i_base + i;

            if (i_shared < sharedBufferSize) {
                int2 uv_i = getSharedUV(i_shared);
                float3 color = texFinal[uv_base + uv_i].rgb;
                sharedBuffer[i_shared] = color;
            }
        }
    }

    barrier();

    if (all(input.globalPos.xy < ap.game.screenSize)) {
        int2 uv = input.localPos.xy + 1;
        //float3 a = sharedBuffer[getSharedIndex(uv + int2(-1,-1))];
        float3 b = sharedBuffer[getSharedIndex(uv + int2( 0,-1))];
        //float3 c = sharedBuffer[getSharedIndex(uv + int2( 1,-1))];
        float3 d = sharedBuffer[getSharedIndex(uv + int2(-1, 0))];
        float3 e = sharedBuffer[getSharedIndex(uv)];
        float3 f = sharedBuffer[getSharedIndex(uv + int2( 1, 0))];
        //float3 g = sharedBuffer[getSharedIndex(uv + int2(-1, 1))];
        float3 h = sharedBuffer[getSharedIndex(uv + int2( 0, 1))];
        //float3 i = sharedBuffer[getSharedIndex(uv + int2( 1, 1))];

        float3 mn;
        mn.r = AMin3F1(AMin3F1(d.r, e.r, f.r), b.r, h.r);
        mn.g = AMin3F1(AMin3F1(d.g, e.g, f.g), b.g, h.g);
        mn.b = AMin3F1(AMin3F1(d.b, e.b, f.b), b.b, h.b);
        
        float3 mx;
        mx.r = AMax3F1(AMax3F1(d.r, e.r, f.r), b.r, h.r);
        mx.g = AMax3F1(AMax3F1(d.g, e.g, f.g), b.g, h.g);
        mx.b = AMax3F1(AMax3F1(d.b, e.b, f.b), b.b, h.b);

        float3 rcpM = rcp(mx);

        float3 amp = saturate(min(mn, 1.0 - mx) * rcpM);
        const float peak = -rcp(lerp(8.0, 5.0, sharpness));
        float3 w = sqrt(amp) * peak;

        float3 rcpWeight = rcp(1.0 + 4.0*w);
        float3 color = saturate(((b + d + f + h) * w + e) * rcpWeight);

        imgFinal[input.globalPos.xy] = float4(color, 1.0);
    }
}
