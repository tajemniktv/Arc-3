import aperture;
import buffers.scene;
import lib.common;
import lib.sampling.atlas;
import lib.sampling.lmcoord;
import lib.material.pbr;
import lib.material.parallax;
import lib.tbn;

extern static const bool RENDER_TERRAIN = false;
extern static const bool RENDER_PARTICLES = false;
extern static const bool TAA_Enabled;

static const bool SupportsParallax = Parallax_Enabled && !RENDER_PARTICLES;
static const bool SupportsTexNormals = !RENDER_PARTICLES;

ConstantBuffer<SceneBuffer> scene;


struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 uv;
    float2 light;
    float3 normal;
    float occlusion;
    float4 tangent;

    float3 localPos;
    float3 tangentViewPos;
    float2 atlasCoordMin;
    float2 atlasCoordSize;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    float3 modelPos = input.pos().xyz;
    float3 viewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(viewPos, 1.0));

    if (SupportsParallax) {
        output.localPos = mul3(ap.camera.viewInv, viewPos);
    }

    output.uv = input.uv();
    output.color = input.color();
    output.occlusion = input.ao();

    output.light = LightMapNorm(input.light());
    output.light = output.light * output.light;

    if (let overlayColor = input.overlayColor()) {
        output.color = lerp(output.color, overlayColor, overlayColor.a);
    }

    float3 viewNormal;
    output.normal = 0.0;
    if (let value = input.normal()) {
        viewNormal = mul(input.normalMatrix(), value);
        output.normal = mul(float3x3(ap.camera.viewInv), viewNormal);
        output.normal = normalize(output.normal);
    }

    float3 viewTangent;
    //output.tangent = 0.0;
    if (SupportsTexNormals || SupportsParallax) {
        if (let value = input.tangent()) {
            output.tangent = value;
            viewTangent = mul(input.normalMatrix(), output.tangent.xyz);
            output.tangent.xyz = mul(float3x3(ap.camera.viewInv), viewTangent);
            output.tangent.xyz = normalize(output.tangent.xyz);
        }
    }

    if (SupportsParallax) {
        if (let midCoord = input.midCoord()) {
            AtlasBounds atlas;
            atlas.Populate(output.uv, midCoord);
            output.atlasCoordMin = atlas.CoordMin;
            output.atlasCoordSize = atlas.CoordSize;
        }

        float3x3 TBN = GetTBN(viewNormal, viewTangent, output.tangent.w);

        float3 viewPos = mul3(ap.camera.view, output.localPos);
        output.tangentViewPos = mul(TBN, viewPos.xyz);
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
    float2 uv = input.uv;
    float LOD = albedoTex.CalculateLevelOfDetail(uv);

    AtlasBounds atlas;
    float3 tanViewDir;
    float texDepth = 1.0;
    float3 traceCoordDepth = 1.0;
    bool skipParallax = false;
    if (SupportsParallax) {
        float viewDist = length(input.localPos);
        tanViewDir = normalize(input.tangentViewPos);

        if (!skipParallax && viewDist < MATERIAL_PARALLAX_MAXDIST) {
            atlas.CoordMin = input.atlasCoordMin;
            atlas.CoordSize = input.atlasCoordSize;

            float2 localCoord = atlas.GetLocalCoord(uv);
            uv = GetParallaxCoord(localCoord, int(LOD), atlas, tanViewDir, viewDist, texDepth, traceCoordDepth);
        }
    }

    float4 color = albedoTex.SampleLevel(uv, LOD) * input.color;
    float4 normalData = normalTex.SampleLevel(uv, LOD);
    float4 specularData = specularTex.SampleLevel(uv, LOD);

    iris_discardIfNeeded(color);

    float3 geo_normal = normalize(input.normal);
    float3 tex_normal = geo_normal;

    if (SupportsTexNormals && MATERIAL_FORMAT != MAT_NONE) {
        tex_normal = mat_normal(normalData.rgb);

        if (SupportsParallax && !skipParallax && Parallax_Type == POM_TYPE_SHARP) {
            float depthDiff = max(texDepth - traceCoordDepth.z, 0.0);

            if (depthDiff >= ParallaxSharpThreshold) {
                tex_normal = GetParallaxSlopeNormal(uv, int(LOD), atlas, traceCoordDepth.z, tanViewDir);
            }
        }

        float3 tangent = normalize(input.tangent.xyz);
        float3x3 TBN = GetTBN(geo_normal, tangent, input.tangent.w);

        tex_normal = normalize(mul(tex_normal, TBN));
    }

    float tex_occlusion = mat_occlusion(normalData.b);
    float occlusion = input.occlusion * tex_occlusion;

    FragmentOutput output;
    output.albedo = color;
    output.normals.r = packUnorm4x8(float4(geo_normal * 0.5 + 0.5, 0.0));
    output.normals.g = packUnorm4x8(float4(tex_normal * 0.5 + 0.5, 0.0));
    output.mat_lit.r = packUnorm4x8(specularData);
    output.mat_lit.g = packUnorm4x8(float4(input.light, occlusion, 0.0));
    output.velocity = 0.0;
    return output;
}
