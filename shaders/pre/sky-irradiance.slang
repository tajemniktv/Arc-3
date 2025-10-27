import aperture;
import buffers.scene;
import lib.common;
import lib.sampling.IGN;
import lib.sampling.ERP;
import lib.sky.common;
import lib.sky.sample_view;

ConstantBuffer<SceneBuffer> scene;


float3 CalculateIrradiance(const in float2 uv, const in float3 normal) {
    const float2 sampleDelta = float2(0.2, 0.1); //0.025;
    const int2 stepCount = int2(PI * float2(2.0, 0.5) / sampleDelta);

    float3 up = float3(0.0, 1.0, 0.0);
//    vec3 T = cross(normal, up);
//    T = mix(cross(normal, vec3(1.0, 0.0, 0.0)), T, step(EPSILON, dot(T, T)));
//    T = normalize(T);
//    vec3 S = normalize(cross(normal, T));
//    mat3 tbn = mat3(S, T, normal);

    float3 right = normalize(cross(up, normal));
    up = normalize(cross(normal, right));

    // float3x3 tbn = float3x3(right, up, normal);
    float3x3 tbn = float3x3(right, up, normal);

    float3 skyPos = getSkyPosition(0.0);

    float dither1 = InterleavedGradientNoise(uv + ap.timing.frameCounter*123.4) * sampleDelta.x;
    float dither2 = InterleavedGradientNoise(uv+7.0 + ap.timing.frameCounter*234.5) * sampleDelta.y;

    float nrSamples = 0.0;
    float3 irradiance = 0.0;

    float phi = dither1;
    for (int x = 0; x < stepCount.x; x++) {
        float cos_phi = cos(phi);
        float sin_phi = sin(phi);

        float theta = dither2;
        for (int y = 0; y < stepCount.y; y++) {
            // spherical to cartesian (in tangent space)
            float cos_theta = cos(theta);
            float sin_theta = sin(theta);

            float3 tangentSample = float3(
                sin_theta * cos_phi,
                sin_theta * sin_phi,
                cos_theta);

            // tangent space to world
            //tangentSample = vec3(0.0, 0.0, 1.0);
            float3 sampleVec = normalize(mul(tangentSample, tbn));

            // vec2 uv = DirectionToUV(sampleVec);
            // vec3 skyColor = textureLod(texSkyView, uv, 0).rgb;

            float3 skyColor = sampleSkyView(skyPos, sampleVec, scene.SunLocalDir);

//            if (rayIntersectSphere(skyPos, sampleVec, groundRadiusMM) < 0.0) {
//                float sunLum = SUN_LUMINANCE * sun(sampleVec, Scene_LocalSunDir);
//                float moonLum = MOON_LUMINANCE * moon(sampleVec, -Scene_LocalSunDir);
//
//                vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, sampleVec);
//
//                skyColor += (sunLum * Scene_SunColor + moonLum) * skyTransmit;
//            }

            irradiance += skyColor * (cos_theta * sin_theta);
            nrSamples++;

            theta += sampleDelta.y;
        }

        phi += sampleDelta.x;
    }

    return irradiance / nrSamples;
}

[[shader("fragment")]]
float4 bakeSkyIrradiance(float2 pos : SV_Position) : SV_Target0 {
    float2 uv = pos / float2(skyIrradianceDimensions);

    float3 viewDir = DirectionFromUV(uv);
    float3 irradiance = CalculateIrradiance(pos, viewDir) * PI;

    // irradiance = float3(viewDir * 0.5 + 0.5);

    return float4(irradiance, 0.1);
}
