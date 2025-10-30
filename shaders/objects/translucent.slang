import aperture;
import buffers.scene;
import lib.common;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.shadow;
import lib.material.pbr;
import lib.material.parallax;
import lib.tbn;

extern static const bool RENDER_TERRAIN = false;
extern static const bool RENDER_PARTICLES = false;
extern static const bool TAA_Enabled;
extern static const bool Debug_WhiteWorld;

static const bool SupportsParallax = Parallax_Enabled && !RENDER_PARTICLES;
static const bool SupportsTexNormals = !RENDER_PARTICLES;

struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 uv;
    float2 light;
    float3 normal;
    float occlusion;
    float4 tangent;
    float3 localPos;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    float3 modelPos = input.pos().xyz;
    float3 viewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(viewPos, 1.0));
    output.localPos = mul3(ap.camera.viewInv, viewPos);

    output.uv = input.uv();
    output.color = input.color();
    output.light = input.light();

    output.occlusion = 1.0;
    if (RENDER_TERRAIN) {
        output.occlusion = input.ao();
    }

    output.normal = 0.0;//mul(float3x3(ap.camera.viewInv), float3(0,0,1));
    if (let normal = input.normal()) {
        output.normal = mul(input.normalMatrix(), normal);
        output.normal = mul(float3x3(ap.camera.viewInv), output.normal);
    }

    //output.tangent = 0.0;
    if (SupportsTexNormals) {
        if (let value = input.tangent()) {
            output.tangent.xyz = mul(input.normalMatrix(), value.xyz);
            output.tangent.xyz = mul(float3x3(ap.camera.viewInv), output.tangent.xyz);
            output.tangent.xyz = normalize(output.tangent.xyz);
            output.tangent.w = value.w;
        }
    }

    if (let overlayColor = input.overlayColor()) {
        output.color = lerp(output.color, overlayColor, overlayColor.a);
    }

    if (TAA_Enabled) {
        output.position.xy += scene[0].taa_jitter * (2.0 * output.position.w);
    }

    return output;
}


struct FragmentOutput {
    float4 color : SV_Target0;
    //float2 velocity : SV_Target2;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float LOD = albedoTex.CalculateLevelOfDetail(input.uv);

    float4 albedo = albedoTex.SampleLevel(input.uv, LOD) * input.color;
    iris_discardIfNeeded(albedo);

    albedo.rgb = RgbToLinear(albedo.rgb);
    if (Debug_WhiteWorld) albedo.rgb = 0.85;

    float4 normalData = normalTex.SampleLevel(input.uv, LOD);

    bool has_normal = true;
    float3 geo_normal = 0.0;
    if (dot(input.normal, input.normal) > EPSILON)
        geo_normal = normalize(input.normal);
    else has_normal = false;

    float3 tex_normal = geo_normal;
    if (SupportsTexNormals) {
        tex_normal = mat_normal(normalData.rgb);

        float3 tangent = normalize(input.tangent.xyz);
        float3x3 TBN = GetTBN(geo_normal, tangent, input.tangent.w);

        tex_normal = normalize(mul(tex_normal, TBN));
    }

    float lmcoord_y = input.light.g*input.light.g;

    float geo_NoLm = 1.0;
    if (has_normal) geo_NoLm = 1.0 - abs(dot(geo_normal, scene[0].SkyLightLocalDir));

    float viewDist = length(input.localPos);
    float normal_bias = geo_NoLm * (viewDist * 0.006 + 0.06);
    float offset_bias = viewDist * 0.002;

    float3 shadowLocalPos = geo_normal * normal_bias + input.localPos;
    float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
    shadowViewPos.z += offset_bias;

    const float paddingBlocks = 0.05;
    int shadowCascade = GetShadowProjection(shadowViewPos, paddingBlocks);

    float shadow = 1.0;
    if (shadowCascade >= 0) {
        float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos).xyz * 0.5 + 0.5;
        shadow = SampleShadow(shadowPos, shadowCascade);
    }

    float3 skyPos = getSkyPosition(input.localPos);

    float NoLm_sun = 1.0;
    if (has_normal) NoLm_sun = max(dot(tex_normal, scene[0].SunLocalDir), 0.0);
    float3 sunTransmit = sampleSkyTransmit(skyPos, scene[0].SunLocalDir);
    float3 lightSun = NoLm_sun * sunTransmit * scene[0].SunColor;

    float NoLm_moon = 1.0;
    if (has_normal) NoLm_moon = max(dot(tex_normal, scene[0].MoonLocalDir), 0.0);
    float3 moonTransmit = sampleSkyTransmit(skyPos, scene[0].MoonLocalDir);
    float3 lightMoon = NoLm_moon * moonTransmit * scene[0].MoonColor;

    float3 ambient_normal = has_normal ? tex_normal : float3(0.0, 1.0, 0.0);
    float3 ambient = sampleSkyIrradiance(ambient_normal) * lmcoord_y * input.occlusion;

    // TODO: SSS

    float3 diffuse = (lightSun + lightMoon) / PI * shadow + ambient;
    float3 specular = 0.0;

    float4 color = albedo;
    color.rgb = color.rgb * diffuse + specular;

    FragmentOutput output;
    output.color = color;
    //output.velocity = 0.0;
    return output;
}
