import aperture;
import buffers.scene;
import lib.common;
import lib.sampling.lmcoord;
import lib.material;
import lib.tbn;

extern static const bool disableFog;
extern static const bool TAA_Enabled;

ConstantBuffer<SceneBuffer> scene;
Sampler2D shit;


// Hack for bad tangent; stolen from Kappa, stolen from MollyVX
float3x3 manualTBN(float3 pos, float3 normal, float2 uv) {
    uv *= float2(16000);//albedoTex.GetDimensions();

    float3 deltaPosX = ddx(pos);
    float3 deltaPosY = ddy(pos);
    float2 deltaUVX = ddx(uv);
    float2 deltaUVY = ddy(uv);

    float3 deltaPosXPerp   = cross(normal, deltaPosX);
    float3 deltaPosYPerp   = cross(deltaPosY, normal);

    float3 tangent   = normalize(deltaPosYPerp * deltaUVX.x + deltaPosXPerp * deltaUVY.x);
    float3 bitangent = normalize(deltaPosYPerp * deltaUVX.y + deltaPosXPerp * deltaUVY.y);

    return float3x3(tangent, bitangent, normal);
}


struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 uv;
    float2 light;
    float3 normal;
    float occlusion;
    float4 tangent;
    // float3 localPos;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    float3 modelPos = input.pos().xyz;
    float3 viewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(viewPos, 1.0));

    // output.localPos = mul3(ap.camera.viewInv, viewPos);

    output.uv = input.uv();
    output.color = input.color();
    output.occlusion = input.ao();

    output.light = LightMapNorm(input.light());
    output.light = output.light * output.light;

    if (let overlayColor = input.overlayColor()) {
        output.color = lerp(output.color, overlayColor, overlayColor.a);
    }

    output.normal = 0.0;
    if (let value = input.normal()) {
        output.normal = mul(input.normalMatrix(), value);
        output.normal = mul(float3x3(ap.camera.viewInv), output.normal);
        output.normal = normalize(output.normal);
    }

    output.tangent = 0.0;
    if (let value = input.tangent()) {
        output.tangent = value;
        output.tangent.xyz = mul(input.normalMatrix(), output.tangent.xyz);
        output.tangent.xyz = mul(float3x3(ap.camera.viewInv), output.tangent.xyz);
        output.tangent.xyz = normalize(output.tangent.xyz);
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
    float LOD = albedoTex.CalculateLevelOfDetail(input.uv);

    float4 color = albedoTex.SampleLevel(input.uv, LOD) * input.color;
    iris_discardIfNeeded(color);

    float4 normalData = normalTex.SampleLevel(input.uv, LOD);
    float4 specularData = specularTex.SampleLevel(input.uv, LOD);

    float3 geo_normal = normalize(input.normal);
    float3 tex_normal = geo_normal;

    if (MATERIAL_FORMAT != MAT_NONE) {
        tex_normal = mat_normal(normalData.rgb);
        float3 tangent = normalize(input.tangent.xyz);
        float3x3 TBN = GetTBN(geo_normal, tangent, input.tangent.w);
        //TBN = transpose(TBN);
        // float3x3 TBN = manualTBN(input.localPos, geo_normal, input.uv);
        tex_normal = normalize(mul(tex_normal, TBN));
    }

    float occlusion = input.occlusion * normalData.b;

    FragmentOutput output;
    output.albedo = color;
    output.normals.r = packUnorm4x8(float4(geo_normal * 0.5 + 0.5, 0.0));
    output.normals.g = packUnorm4x8(float4(tex_normal * 0.5 + 0.5, 0.0));
    output.mat_lit.r = packUnorm4x8(specularData);
    output.mat_lit.g = packUnorm4x8(float4(input.light, occlusion, 0.0));
    output.velocity = 0.0;
    return output;
}
