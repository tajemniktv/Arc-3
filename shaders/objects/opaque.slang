import aperture;
import buffers.scene;
import lib.common;

extern static const bool EnableTAA;
extern static const bool disableFog;

ConstantBuffer<SceneBuffer> scene;

struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 uv;
    float2 light;
    float3 normal;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    float4 modelPos = input.pos();

    output.position = mul(input.projectionMatrix(), mul(input.viewMatrix(), modelPos));
    output.uv = input.uv();
    output.color = input.color();
    output.light = input.light();

    if (let normal = input.normal()) {
        output.normal = mul(input.normalMatrix(), normal);
        output.normal = mul(float3x3(ap.camera.viewInv), output.normal);
    }

    if (let overlayColor = input.overlayColor()) {
        output.color = lerp(output.color, overlayColor, overlayColor.a);
    }

    if (EnableTAA) {
        output.position.xy += scene.taa_jitter * (2.0 * output.position.w);
    }

    return output;
}


struct FragmentOutput {
    float4 albedo : SV_Target0;
    uint2 normals : SV_Target1;
    float2 velocity : SV_Target2;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float4 color = albedoTex.Sample(input.uv) * input.color;
    iris_discardIfNeeded(color);

    float3 tex_normal = normalize(input.normal);

    FragmentOutput output;
    output.albedo = color;
    output.normals.r = packUnorm4x8(float4(input.normal * 0.5 + 0.5, 0.0));
    output.normals.g = packUnorm4x8(float4(tex_normal * 0.5 + 0.5, 0.0));
    output.velocity = 0.0;
    return output;
}
