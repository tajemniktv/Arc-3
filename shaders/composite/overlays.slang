import aperture;
import lib.common;
import lib.sampling.depth;

extern static const int RefractMode;

static const int REFRACTION_STEPS = 16;
static const int Refract_ScreenSpace = 1;

Sampler2D<float> mainDepthTex;
Sampler2D<float> solidDepthTex;

Sampler2D<half3> texSource;
Sampler2D<half4> texFinalTranslucent;
Sampler2D<half3> texNormalTranslucent;
Sampler2D<half3> texTintTranslucent;
Sampler2D<half4> texWeather;


void ss_refract(inout float2 uv, const in float3 viewPos, const in float3 refractLocalNormal, float eta) {
    // const float3 viewDir = float3(0.0, 0.0, -1.0);
    float3 viewDir = normalize(viewPos);
    float3 refractViewNormal = mul(float3x3(ap.camera.view), refractLocalNormal);
    float3 refractViewDir = refract(viewDir, refractViewNormal, eta);

    float viewDist = length(viewPos);
    float3 refractViewEnd = viewPos + 0.2 * viewDist * normalize(refractViewDir);
    float3 screenStart = project(ap.camera.projection, viewPos) * 0.5 + 0.5;
    float3 screenEnd = project(ap.camera.projection, refractViewEnd) * 0.5 + 0.5;

    float3 screenStep = screenEnd - screenStart;
    screenStep /= length(screenStep.xy);
    screenStep /= ap.game.screenSize.x;
    screenStep *= 4.0;
    // TODO: aspect correct?

    for (int i = 1; i <= 32; i++) {
        float3 tracePos = i * screenStep + screenStart;
        float depth_opaque = solidDepthTex.Sample(tracePos.xy).r;
        if (depth_opaque < tracePos.z) break;
        uv = tracePos.xy;
    }
}


[[shader("fragment")]]
float4 applyOverlays(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);

    half4 weather = texWeather[uv];
    half3 tint = texTintTranslucent[uv];
    half4 translucent = texFinalTranslucent[uv];

    float2 refract_uv = pos / ap.game.screenSize;

    if (RefractMode == Refract_ScreenSpace && translucent.a > 0.0) {
        float3 refract_localNormal = texNormalTranslucent[uv];
        refract_localNormal = normalize(refract_localNormal * 2.0 - 1.0);

        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float depth = mainDepthTex[uv];
        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        // float3 localPos = mul3(ap.camera.viewInv, viewPos);

        const float IOR_AIR   = 1.00;
        const float IOR_WATER   = 1.33;
        const float IOR_DEFAULT = 1.50;
        // TODO: store and use actual translucent IOR
        const float ETA_TO_WATER = (IOR_AIR/IOR_WATER);
        const float ETA_FROM_WATER = (IOR_WATER/IOR_AIR);
        float eta = ETA_TO_WATER;//ap.camera.fluid;

        ss_refract(refract_uv, viewPos, refract_localNormal, eta);
    }

    half3 opaque_color = texSource.Sample(refract_uv);
    opaque_color *= RgbToLinear(tint);

    half3 final_color = lerp(opaque_color, translucent.rgb, translucent.a);

    final_color.rgb += weather.rgb * half3(0.25);

    return half4(final_color, half2(1.0).x);
}
