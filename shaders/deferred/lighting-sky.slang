import aperture;
import buffers.scene;
import lib.common;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<float> mainDepthTex;


struct FragmentOutput {
    float3 diffuse : SV_Target0;
    float3 specular : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput lightingSky(float2 pos : SV_Position) {
    FragmentOutput output;
    uint2 uv = uint2(pos);

    float depth = mainDepthTex[uv];
    float2 texcoord = pos / ap.game.screenSize;
    float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = unproject(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);

    //float4 albedo = texAlbedoGB[uv];
    uint2 normals = texNormalGB[uv];
    //float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
    float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);
    float2 lmcoord = 1.0; // TODO
    
    float3 skyPos = getSkyPosition(localPos);

    float3 sunTransmit = sampleSkyTransmit(skyPos, scene.SunLocalDir);
    float NoLm_sun = max(dot(tex_normal, scene.SunLocalDir), 0.0);
    float3 lightSun = NoLm_sun * sunTransmit * scene.SunColor;

    float3 moonTransmit = sampleSkyTransmit(skyPos, scene.MoonLocalDir);
    float NoLm_moon = max(dot(tex_normal, scene.MoonLocalDir), 0.0);
    float3 lightMoon = NoLm_moon * moonTransmit * scene.MoonColor;

    //float3 viewLocalDir = normalize(localPos);
    float3 ambient = sampleSkyIrradiance(tex_normal, lmcoord.y);

    output.diffuse = (lightSun + lightMoon) / PI + ambient;
    output.specular = 0.0;

    return output;
}
