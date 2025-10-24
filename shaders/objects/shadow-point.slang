import aperture;
import lib.common;


extern static const bool LIGHTING_SHADOW_EMISSION_MASK = false;

struct VertexOutput {
    float4 position : SV_Position;

    float3 modelPos;
    nointerpolation uint blockId;
    float2 uv;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    output.uv = input.uv();
    output.modelPos = input.pos().xyz;

    output.blockId = -1;
    if (let value = input.blockId()) output.blockId = value;

    PointLight light = ap.lights[input.currentInstance()];

    float3 shadowViewPos = mul3(input.viewMatrix(), output.modelPos);

    // if (SKY_WIND_ENABLED) {
    //     float3 localPos = output.modelPos + light.position;

    //     float3 midPos = input.midBlock().value / 64.0;
    //     float3 originPos = localPos + midPos;
    //     float3 wavingOffset = GetWavingOffset(originPos, midPos, output.blockId);

    //     output.modelPos += wavingOffset;
    //     shadowViewPos = mul3(input.viewMatrix(), output.modelPos);
    // }

    output.position = mul(input.projectionMatrix(), float4(shadowViewPos, 1.0));

    return output;
}


// #include "/lib/material/material.glsl"
float mat_emission(const in float4 specularData) {
    return 0.0; // TODO
}

[[shader("fragment")]]
float fragmentMain(VertexOutput input) : SV_Depth {
    float LOD = 0.0;//albedoTex.CalculateLevelOfDetail(input.uv);

    float finalDist = length(input.modelPos);
    float fragDepth = (finalDist - ap.lights.nearPlane) / (ap.lights.farPlane - ap.lights.nearPlane);

    float alpha = albedoTex.SampleLevel(input.uv, LOD).a;

    if (LIGHTING_SHADOW_EMISSION_MASK) {
        if (all(clamp(input.modelPos, -0.5, 0.5) == input.modelPos)) {
            float4 specularData = specularTex.SampleLevel(input.uv, LOD);
            float emission = mat_emission(specularData);
            if (emission > 0.0) alpha = 0.0;
        }
    }
    else {
        bool isFull = input.blockId >= 0 && ap.blocks[input.blockId].isFullBlock;
        float near = isFull ? 0.5 : 0.49999;

        if (all(clamp(input.modelPos, -near, near) == input.modelPos)) alpha = 0.0;
    }

    const float alphaThreshold = 0.2;
    if (alpha < alphaThreshold) discard;

    return fragDepth;
}
