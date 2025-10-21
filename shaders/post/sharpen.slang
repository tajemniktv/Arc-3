import aperture;
import lib.common;

// https://github.com/GPUOpen-Effects/FidelityFX-CAS/blob/master/ffx-cas/ffx_cas.h#L423

[[vk::image_format("rgba16f")]]
RWTexture2D<float4> imgFinal;

extern static const float sharpness = 0.5;

static const uint groupRes = 16;
static const uint sharedBufferRes = groupRes+2;
static const uint sharedBufferSize = sharedBufferRes*sharedBufferRes;
groupshared float3 sharedBuffer[sharedBufferSize];


int getSharedIndex(const in int2 uv) {
    // TODO: morton index?
    return uv.y * sharedBufferRes + uv.x;
}

float AMin3F1(float x, float y, float z) {
    return min(x, min(y, z));
}

float AMax3F1(float x, float y, float z) {
    return max(x, max(y, z));
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
[numthreads(groupRes,groupRes,1)]
void sharpen(ComputeInput input) {
    uint i_base = input.groupIndex * 2u;

    if (i_base < sharedBufferSize) {
        uint2 uv_base = input.groupPos.xy * groupRes - 1u;

        for (uint i = 0u; i < 2u; i++) {
            uint i_shared = i_base + i;

            if (i_shared < sharedBufferSize) {
                int2 uv_i = int2(
                    i_shared % sharedBufferRes,
                    int(i_shared / float(sharedBufferRes))
                );

                float3 color = imgFinal[uv_base + uv_i].rgb;
                sharedBuffer[i_shared] = color;
            }
        }
    }

    barrier();

    if (all(input.globalPos.xy < ap.game.screenSize)) {
        int2 uv = input.localPos.xy + 1;
        float3 a = sharedBuffer[getSharedIndex(uv + int2(-1,-1))];
        float3 b = sharedBuffer[getSharedIndex(uv + int2( 0,-1))];
        float3 c = sharedBuffer[getSharedIndex(uv + int2( 1,-1))];
        float3 d = sharedBuffer[getSharedIndex(uv + int2(-1, 0))];
        float3 e = sharedBuffer[getSharedIndex(uv)];
        float3 f = sharedBuffer[getSharedIndex(uv + int2( 1, 0))];
        float3 g = sharedBuffer[getSharedIndex(uv + int2(-1, 1))];
        float3 h = sharedBuffer[getSharedIndex(uv + int2( 0, 1))];
        float3 i = sharedBuffer[getSharedIndex(uv + int2( 1, 1))];

        float3 mn;
        mn.r = AMin3F1(AMin3F1(d.r, e.r, f.r), b.r, h.r);
        mn.g = AMin3F1(AMin3F1(d.g, e.g, f.g), b.g, h.g);
        mn.b = AMin3F1(AMin3F1(d.b, e.b, f.b), b.b, h.b);
        
        float3 mx;
        mx.r = AMax3F1(AMax3F1(d.r, e.r, f.r), b.r, h.r);
        mx.g = AMax3F1(AMax3F1(d.g, e.g, f.g), b.g, h.g);
        mx.b = AMax3F1(AMax3F1(d.b, e.b, f.b), b.b, h.b);

        float3 rcpM = rcp(mx);

        float3 amp = saturate(min(mn, 1.0f - mx) * rcpM);

        amp = sqrt(amp);

        const float peak = -rcp(lerp(8.0f, 5.0f, sharpness));
        float3 w = amp * peak;

        float3 rcpWeight = rcp(1.0f + 4.0f*w);

        float3 color;
        // TODO: this looks like a float4x3 multiply
        color.r = (b.r*w.r + d.r*w.r + f.r*w.r + h.r*w.r + e.r);
        color.g = (b.g*w.g + d.g*w.g + f.g*w.g + h.g*w.g + e.g);
        color.b = (b.b*w.b + d.b*w.b + f.b*w.b + h.b*w.b + e.b);

        color = saturate(color * rcpWeight);

        imgFinal[input.globalPos.xy] = float4(color, 1.0);
    }
}
