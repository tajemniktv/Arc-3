import aperture;
import buffers.settings;
import lib.common;
import lib.hg;


ConstantBuffer<SettingsBuffer> settings;

// Units are in megameters.
static const float groundRadiusMM = 6.371;
static const float atmosphereRadiusMM = 0.100 + groundRadiusMM;

static const float3 groundAlbedo = 0.3;

// These are per megameter.
static const float3 rayleighScatteringBase = float3(6.605, 12.344, 29.412);
static const float rayleighAbsorptionBase = 0.0;

static const float mieScatteringBase = 3.996;
static const float mieAbsorptionBase = 4.4;

static const float3 ozoneAbsorptionBase = float3(0.850, 1.581, 0.285);

static const float moon_radiusKm = 1740.0;
static const float moon_distanceKm = 20000.0;

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

//void getScatteringValues(vec3 pos, float stepDist, float sampleDensity, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction) {
//    float altitudeKM = (length(pos)-groundRadiusMM) * 1000.0;
//
//    // Note: Paper gets these switched up.
//    float rayleighDensity = stepDist * 0.0001 * exp(-altitudeKM/8.0);
//    float mieDensity = stepDist*sampleDensity * 0.0001 * exp(-altitudeKM/1.2);
//
//    rayleighScattering = rayleighScatteringBase*rayleighDensity;
//    float rayleighAbsorption = rayleighAbsorptionBase*rayleighDensity;
//
//    mieScattering = mieScatteringBase*mieDensity;
//    float mieAbsorption = mieAbsorptionBase*mieDensity;
//
//    vec3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM-25.0)/15.0);
//
//    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
//}

void getScatteringValues(float3 pos, out float3 rayleighScattering, out float mieScattering, out float3 extinction) {
    float altitudeKM = (length(pos)-groundRadiusMM) * 1000.0;

    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM/8.0);
    float mieDensity = exp(-altitudeKM/1.2);

    rayleighScattering = rayleighScatteringBase*rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase*rayleighDensity;

    mieScattering = mieScatteringBase*mieDensity;
    float mieAbsorption = mieAbsorptionBase*mieDensity;

    float3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM-25.0)/15.0);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
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
