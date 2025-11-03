import aperture;
import lib.common;

extern static const bool ALPHATEST_ENABLED = false;


struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 uv;
    nointerpolation int blockId;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;
    
    output.color = input.color();
    output.uv = input.uv();

    output.blockId = -1;
    if (let value = input.blockId()) output.blockId = value;

    float3 modelPos = input.pos().xyz;
    float3 shadowViewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(shadowViewPos, 1.0));

    if (output.blockId >= 0 && ap.blocks[output.blockId].isFluid) {
        output.color = 1.0;
    }

    return output;
}


[[shader("fragment")]]
float4 fragmentMain(VertexOutput input) : SV_Target0 {
    float4 color = 0;

    if (input.blockId >= 0 && ap.blocks[input.blockId].isFluid) {
        color = float4(1.0, 1.0, 1.0, 0.02);
    }
    else if (ALPHATEST_ENABLED) {
        color = albedoTex.Sample(input.uv) * input.color;
        iris_discardIfNeeded(color);
    }

    return color;
}
