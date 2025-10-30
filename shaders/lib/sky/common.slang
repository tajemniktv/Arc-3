import aperture;
import buffers.scene;
import buffers.settings;
import lib.common;
import lib.hg;


ConstantBuffer<SettingsBuffer> settings;

static const uint2 skyTransmitDimensions = uint2(128, 64);
static const uint2 skyViewDimensions = 256;
static const uint2 skyIrradianceDimensions = 32;

// Units are in megameters.
static const float groundRadiusMM = 6.371;
static const float atmosphereRadiusMM = 0.100 + groundRadiusMM;

static const float3 groundAlbedo = 0.3;

static const float SUN_LUMINANCE = 2000.0;//1.6e6;//1.6e9;
static const float MOON_LUMINANCE = 2.8;

static const float Sky_MinLight = 0.0;


float safeacos(const in float x) {
    return acos(clamp(x, -1.0, 1.0));
}

float3 getSkyPosition(const in float3 localPos) {
    float3 skyPos = localPos;
    skyPos.y = ap.camera.position.y + localPos.y - settings.SkyFogSeaLevel;
    //skyPos /= (ATMOSPHERE_MAX - SKY_SEA_LEVEL);
    //skyPos.y *= 10.0;

    //skyPos *= (atmosphereRadiusMM - groundRadiusMM);
    skyPos *= 0.000001;
    skyPos.y = max(skyPos.y, 0.0002) + groundRadiusMM;

    return skyPos;
}

float getMiePhase(const in float cosTheta, const in float g) {
    float g2 = g*g;

    float num = (1.0 - g2) * (1.0 + cosTheta*cosTheta);
    float denom = (2.0 + g2) * pow((1.0 + g2 - 2.0*g*cosTheta), 1.5);

    const float scale = 3.0 / (8.0*PI);
    return scale * (num / denom);
}

float getMiePhase(float cosTheta) {
    //const float g = 0.8;
    //return getMiePhase(cosTheta, g);

    return DHG(cosTheta, -0.5, 0.8, 0.5);
}

float getRayleighPhase(float cosTheta) {
    const float k = 3.0 / (16.0*PI);
    return k * (1.0 + (cosTheta*cosTheta));
}

// From https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code.
float rayIntersectSphere(float3 ro, float3 rd, float rad) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad*rad;
    if (c > 0.0f && b > 0.0) return -1.0;

    float discr = b*b - c;
    if (discr < 0.0) return -1.0;

    // Special case: inside sphere, use far discriminant
    if (discr > b*b) return (-b + sqrt(discr));
    return -b - sqrt(discr);
}
