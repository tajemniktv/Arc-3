import aperture;
import buffers.scene;
import lib.common;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;

extern static const bool disableFog;
extern static const bool TAA_Enabled;
extern static const bool Debug_WhiteWorld;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float3> texSkyTransmit;

struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 uv;
    float2 light;
    float3 normal;
    float occlusion;
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
    float4 color : SV_Target0;
    float2 velocity : SV_Target2;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float4 albedo = albedoTex.Sample(input.uv) * input.color;
    iris_discardIfNeeded(albedo);

    albedo.rgb = RgbToLinear(albedo.rgb);
    if (Debug_WhiteWorld) albedo.rgb = 0.85;

    float3 geo_normal = normalize(input.normal);
    float3 tex_normal = geo_normal;

    float3 lightDir = normalize(ap.celestial.position);
    // TODO: separate sun/moon direction and color
    float3 localSunDir = normalize(mul(float3x3(ap.camera.viewInv), lightDir));

    float shadow = 1.0;

    float3 skyPos = getSkyPosition(input.localPos);

    float NoLm_sun = max(dot(tex_normal, scene.SunLocalDir), 0.0);
    float NoLm_moon = max(dot(tex_normal, scene.MoonLocalDir), 0.0);

    float3 sunTransmit = sampleSkyTransmit(skyPos, scene.SunLocalDir);
    float3 lightSun = NoLm_sun * sunTransmit * scene.SunColor;

    float3 moonTransmit = sampleSkyTransmit(skyPos, scene.MoonLocalDir);
    float3 lightMoon = NoLm_moon * moonTransmit * scene.MoonColor;

    //float3 viewLocalDir = normalize(localPos);
    float lmcoord_y = input.light.g*input.light.g*input.light.g;
    float3 ambient = sampleSkyIrradiance(tex_normal) * lmcoord_y * input.occlusion;

    float3 diffuse = (lightSun + lightMoon) / PI * shadow + ambient;
    float3 specular = float3(0.0);

    float4 color = albedo;
    color.rgb = color.rgb * diffuse + specular;

    FragmentOutput output;
    output.color = color;
    output.velocity = 0.0;
    return output;
}
