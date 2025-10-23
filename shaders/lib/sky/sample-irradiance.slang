import lib.common;
import lib.sky.common;
import lib.sampling.ERP;

Sampler2D<float3> texSkyIrradiance;

float3 sampleSkyIrradiance(const in float3 localNormal, const in float lmcoord_y) {
    float2 skyIrradianceCoord = DirectionToUV(localNormal);
    return texSkyIrradiance.SampleLevel(skyIrradianceCoord, 0);// * BufferLumScale;
    //return (SKY_AMBIENT * (lmcoord_y*lmcoord_y)) * (skyIrradiance + Sky_MinLight);
}
