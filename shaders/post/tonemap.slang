import aperture;
import buffers.scene;
import lib.common;

extern static const float Scene_PostExposureMin = -4.0;
extern static const float Scene_PostExposureMax = 34.0;
extern static const float Post_ExposureOffset = 4.8;

ConstantBuffer<SceneBuffer> scene;

Sampler2D<float4> texSource;

static const float3x3 RGB_TO_XYZ = float3x3(
    0.4124564, 0.3575761, 0.1804375,
    0.2126729, 0.7151522, 0.0721750,
    0.0193339, 0.1191920, 0.9503041);

static const float3x3 XYZ_TO_RGB = float3x3(
     3.2404542, -1.5371385, -0.4985314,
    -0.9692660,  1.8760108,  0.0415560,
     0.0556434, -0.2040259,  1.0572252);

float3 xyz_to_xyY(float3 xyz) {
	float sum = sumOf(xyz);
    return float3(xyz.xy / sum, xyz.y);
}

float3 xyY_to_xyz(float3 xyY) {
    float2 xz = float2(xyY.x, 1.0 - xyY.x - xyY.y);
    return float3(xyY.z * xz.xy / xyY.y, xyY.z).xzy;
}

float ev_100(const in float luminance, const in float luminance_avg) {
    return luminance / (9.6 * max(luminance_avg, 1.0e-8));
}

void ApplyAutoExposure(inout float3 rgb, const in float avgLum) {
	float3 xyY = xyz_to_xyY(mul(RGB_TO_XYZ, rgb));

	//float lp = xyY.z / (9.6 * avgLum + 0.0001);
    float lp = ev_100(xyY.z, avgLum);

	//const float whitePoint = Scene_PostExposureRange;
    //xyY.z = reinhard2(lp, whitePoint);
    xyY.z = lp * exp2(-Post_ExposureOffset);// * 0.08;

	rgb = mul(XYZ_TO_RGB, xyY_to_xyz(xyY));
}

static const float3x3 REC2020_TO_SRGB = float3x3(
    1.6605, -0.5876, -0.0728,
    -0.1246, 1.1329, -0.0083,
    -0.0182, -0.1006, 1.1187);

static const float3x3 LINEAR_RGB_TO_REC2020 = float3x3(
    0.6274, 0.3293, 0.0433,
    0.0691, 0.9195, 0.0113,
    0.0164, 0.0880, 0.8956);

float3 tonemap_ACESFit2(const in float3 color) {
    static const float3x3 m1 = float3x3(
        0.59719, 0.35458, 0.04823,
        0.07600, 0.90834, 0.01566,
        0.02840, 0.13383, 0.83777);

    static const float3x3 m2 = float3x3(
        1.60475, -0.53108, -0.07367,
        -0.10208, 1.10813, -0.00605,
        -0.00327, -0.07276, 1.07602);

    float3 v = mul(m1, color);
    float3 a = v * (v + 0.0245786) - 0.000090537;
    float3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return saturate(mul(m2, a / b));
}


[[shader("fragment")]]
float4 tonemap(float2 pos : SV_Position) : SV_Target0 {
    float3 color = texSource[int2(pos)].rgb;

    // TODO: exposure
    float exposureF = clamp(scene.exposure, Scene_PostExposureMin, Scene_PostExposureMax);
    //ApplyAutoExposure(color, exposureF);

    color = mul(LINEAR_RGB_TO_REC2020, color);

    color = tonemap_ACESFit2(color);

    color = mul(REC2020_TO_SRGB, color);

    return float4(color, 1.0);
}
