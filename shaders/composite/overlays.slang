import aperture;
import lib.common;

static const int REFRACTION_STEPS = 8;

Sampler2D<float> solidDepthTex;
Sampler2D<half3> texSource;
Sampler2D<half4> texFinalTranslucent;
Sampler2D<half3> texNormalTranslucent;
Sampler2D<half3> texTintTranslucent;
Sampler2D<half4> texWeather;


[[shader("fragment")]]
float4 applyOverlays(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);

    half4 weather = texWeather[uv];
    half3 tint = texTintTranslucent[uv];
    half4 tranlsucent = texFinalTranslucent[uv];
    float3 tranlsucent_normal = texNormalTranslucent[uv];

    tranlsucent_normal = normalize(tranlsucent_normal * 2.0 - 1.0);

    // TODO: refraction tracing?
    float2 refract_uv = pos / ap.game.screenSize;
    // float3 refractViewNormal = mul(float3x3(ap.camera.view), refractSurfaceNormal - localGeoNormal);

    // const float refractEta = (IOR_AIR/IOR_WATER);
    // const float3 refractViewDir = float3(0.0, 0.0, 1.0);
    // float3 refractDir = refract(refractViewDir, refractViewNormal, refractEta);

    // float2 refractMax = 0.2;
    // refractMax.x *= ap.game.screenSize.x / ap.game.screenSize.y;
    // float2 refraction = clamp(float2(0.025 * linearDist), -refractMax, refractMax) * refractDir.xy;

    // float2 refractStep = refraction / REFRACTION_STEPS;

    // for (int i = 0; i < REFRACTION_STEPS; i++) {
    //     float2 sample_uv = refract_uv + refractStep;
    //     float sample_depth = solidDepthTex.Sample(sample_uv).r;

    //     if (depthTrans > sample_depth) break;
    //     refract_uv = sample_uv;
    // }

    half3 opaque_color = texSource.Sample(refract_uv);
    opaque_color *= RgbToLinear(tint);

    half3 final_color = lerp(opaque_color, tranlsucent.rgb, tranlsucent.a);

    final_color.rgb += weather.rgb * half3(0.25);

    return half4(final_color, half2(1.0).x);
}
