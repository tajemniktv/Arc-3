import lib.common;
import lib.light.fresnel;

// Attenuation - Power curve falloff
float GetLightAttenuation_Linear(const in float lightDist, const in float lightRange) {
    float lightDistF = lightDist / lightRange;
    lightDistF = 1.0 - saturate(lightDistF);
    return pow(lightDistF, 5);
}

// Attenuation - Inverse square law
float GetLightAttenuation_invSq(const in float lightDist, const in float lightRadius) {
    return 1.0 / ((lightDist*lightDist) + lightRadius);
}

// Attenuation MODE 0: Legacy - blend between linear and inverse square
float GetLightAttenuation_Legacy(const in float lightDist, const in float lightRange, const in float lightRadius) {
    float linear = GetLightAttenuation_Linear(lightDist, lightRange);
    float invSq = GetLightAttenuation_invSq(max(lightDist-lightRadius, 0.0), lightRadius);

    float f = saturate(lightDist / lightRange);
    return lerp(invSq, linear, f);
}

// Attenuation MODE 1: Windowed - smooth window function (RECOMMENDED)
float GetLightAttenuation_Windowed(const in float lightDist, const in float lightRange) {
    float distNorm = saturate(lightDist / lightRange);
    float window = 1.0 - (distNorm * distNorm);
    window = window * window;
    
    float physicalAtten = 1.0 / (1.0 + lightDist * lightDist);
    return physicalAtten * window;
}

// Attenuation MODE 2: Physical - pure inverse square law
float GetLightAttenuation_Physical(const in float lightDist, const in float lightRange) {
    float distNorm = saturate(lightDist / lightRange);
    if (distNorm >= 1.0) return 0.0;
    
    return 1.0 / (1.0 + lightDist * lightDist);
}

// Main attenuation function - dispatches to selected mode
extern static const int LIGHTING_ATTENUATION_MODE;

float GetLightAttenuation(const in float lightDist, const in float lightRange, const in float lightRadius) {
    if (LIGHTING_ATTENUATION_MODE == 1) {
        return GetLightAttenuation_Windowed(lightDist, lightRange);
    }
    else if (LIGHTING_ATTENUATION_MODE == 2) {
        return GetLightAttenuation_Physical(lightDist, lightRange);
    }
    else {
        return GetLightAttenuation_Legacy(lightDist, lightRange, lightRadius);
    }
}

// ============================================================================
// BRDF Functions (Original)
// ============================================================================

// Disney Diffuse BRDF
float SampleLightDiffuse(const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float f90 = 0.5 + 2.0*roughL * (LoH*LoH);
    float light_scatter = F_schlick(NoL, 1.0, f90);
    float view_scatter = F_schlick(NoV, 1.0, f90);
    //return light_scatter * view_scatter; // / PI;
    return (light_scatter * view_scatter) / PI;
}

// GGX Normal Distribution Function
float D_GGX(const in float NoH, const in float roughL) {
    float a2 = roughL * roughL;
    float f = (NoH * a2 - NoH) * NoH + 1.0;
    return a2 / (PI * f * f);
}

// Smith GGX Visibility Function (Original version)
float V_SmithGGXCorrelated(float NdotL, float NdotV, float roughness) {
    float a = roughness * roughness;
    float k = (a + 1.0) * (a + 1.0) / 8.0;
    float G_V = NdotV / (NdotV * (1.0 - k) + k);
    float G_L = NdotL / (NdotL * (1.0 - k) + k);
    return G_V * G_L;
}

// Specular BRDF (Original version)
float3 SampleLightSpecular(float NoL, float NoH, float NoV, float3 F_VoH, float roughL) {
    float D = D_GGX(NoH, roughL);
    float G = V_SmithGGXCorrelated(NoL, NoV, roughL);
    
    float3 numerator = D * G * F_VoH;
    float denominator = 4.0 * NoL * NoV + 0.0001;
    return numerator / denominator;
}

