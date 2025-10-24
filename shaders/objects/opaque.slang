import aperture;
import buffers.scene;
import lib.common;

extern static const bool disableFog;
extern static const bool TAA_Enabled;

ConstantBuffer<SceneBuffer> scene;

struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 uv;
    float2 light;
    float3 normal;
    float occlusion;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    float4 modelPos = input.pos();

    output.position = mul(input.projectionMatrix(), mul(input.viewMatrix(), modelPos));
    output.uv = input.uv();
    output.color = input.color();
    output.light = input.light();
    output.occlusion = input.ao();

    output.normal = 0.0;
    if (let normal = input.normal()) {
        output.normal = mul(input.normalMatrix(), normal);
        output.normal = mul(float3x3(ap.camera.viewInv), output.normal);
    }

    if (let overlayColor = input.overlayColor()) {
        output.color = lerp(output.color, overlayColor, overlayColor.a);
    }

    if (TAA_Enabled) {
        output.position.xy += scene.taa_jitter * (2.0 * output.position.w);
    }

    return output;
}


struct FragmentOutput {
    float4 albedo : SV_Target0;
    uint2 normals : SV_Target1;
    uint2 mat_lit : SV_Target2;
    float2 velocity : SV_Target3;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float4 color = albedoTex.Sample(input.uv) * input.color;
    iris_discardIfNeeded(color);

    float3 tex_normal = normalize(input.normal);

    float occlusion = input.occlusion;
    float emission = 0.0;//?

    FragmentOutput output;
    output.albedo = color;
    output.normals.r = packUnorm4x8(float4(input.normal * 0.5 + 0.5, 0.0));
    output.normals.g = packUnorm4x8(float4(tex_normal * 0.5 + 0.5, 0.0));
    output.mat_lit.r = packUnorm4x8(float4(0.0));
    output.mat_lit.g = packUnorm4x8(float4(input.light, occlusion, emission));
    output.velocity = 0.0;
    return output;
}
