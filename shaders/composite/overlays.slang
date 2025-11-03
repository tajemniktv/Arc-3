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


void ss_refract(inout float2 uv, const in float3 refractLocalNormal, float eta) {
    const float3 refractViewDir = float3(0.0, 0.0, 1.0);
    float3 refractViewNormal = mul(float3x3(ap.camera.view), refractLocalNormal);
    float3 refractDir = refract(refractViewDir, refractViewNormal, eta);

    float2 refractMax = 0.2;
    refractMax.x *= ap.game.screenSize.x / float(ap.game.screenSize.y);

    float opaqueDepth = solidDepthTex.Sample(uv).r * 2.0 - 1.0;
    float opaqueDepthL = linearizeDepth(opaqueDepth, ap.camera.near, ap.camera.far);
    float transDepth = mainDepthTex.Sample(uv).r * 2.0 - 1.0;
    float transDepthL = linearizeDepth(transDepth, ap.camera.near, ap.camera.far);
    float linearDist = max(opaqueDepthL - transDepthL, 0.0);

    float2 refraction = clamp(float2(0.0125 * linearDist), -refractMax, refractMax) * refractDir.xy;

    float2 refractStep = refraction / REFRACTION_STEPS;

    for (int i = 0; i < REFRACTION_STEPS; i++) {
        float2 sample_uv = uv + refractStep;
        float depth_opaque = solidDepthTex.Sample(sample_uv).r;
        float depth_trans = mainDepthTex.Sample(sample_uv).r;

        if (depth_trans >= depth_opaque) break;
        uv = sample_uv;
    }
}


[[shader("fragment")]]
float4 applyOverlays(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);

    half4 weather = texWeather[uv];
    half3 tint = texTintTranslucent[uv];
    half4 tranlsucent = texFinalTranslucent[uv];

    float2 refract_uv = pos / ap.game.screenSize;

    if (RefractMode == Refract_ScreenSpace) {
        float3 refract_localNormal = texNormalTranslucent[uv];
        refract_localNormal = normalize(refract_localNormal * 2.0 - 1.0);

        const float IOR_AIR   = 1.00;
        const float IOR_DEFAULT = 1.50;
        // TODO: store and use actual translucent IOR
        const float eta = (IOR_AIR/IOR_DEFAULT);

        ss_refract(refract_uv, refract_localNormal, eta);
    }

    half3 opaque_color = texSource.Sample(refract_uv);
    opaque_color *= RgbToLinear(tint);

    half3 final_color = lerp(opaque_color, tranlsucent.rgb, tranlsucent.a);

    final_color.rgb += weather.rgb * half3(0.25);

    return half4(final_color, half2(1.0).x);
}
