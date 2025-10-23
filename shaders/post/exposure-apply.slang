import aperture;
import buffers.scene;
import lib.common;

extern static const float Scene_PostExposureMin;
extern static const float Scene_PostExposureMax;
extern static const float Scene_PostExposureRange = 6.4; // 9.6
extern static const float Scene_PostExposureOffset;

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
    return luminance / (Scene_PostExposureRange * max(luminance_avg, 1.0e-8));
}


[[shader("fragment")]]
float4 applyExposure(float2 pos : SV_Position) : SV_Target0 {
    float3 color = texSource[int2(pos)].rgb;

    float3 xyY = xyz_to_xyY(mul(RGB_TO_XYZ, color));

    float exposureF = clamp(scene.exposure, Scene_PostExposureMin, Scene_PostExposureMax);

    float lp = ev_100(xyY.z, exposureF);
    xyY.z = lp * exp2(-Scene_PostExposureOffset);

	color = mul(XYZ_TO_RGB, xyY_to_xyz(xyY));

    return float4(color, 1.0);
}
