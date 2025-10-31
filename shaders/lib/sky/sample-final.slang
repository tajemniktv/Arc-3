import lib.common;
import buffers.scene;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_view;
import lib.sky.moon;
import lib.sky.sun;

extern static const bool WORLD_OVERWORLD = true;

// ConstantBuffer<SceneBuffer> scene;

float3 sampleSkyFinal(const in float3 localPos, const in float3 viewLocalDir, bool isReflection) {
    // float3 starViewDir = getStarViewDir(viewLocalDir);
    float3 skyLight = 0;//STAR_LUMINANCE * GetStarLight(starViewDir);

    float3 skyPos;
    bool intersectsPlanet;
    if (WORLD_OVERWORLD) {
        skyPos = getSkyPosition(localPos);
        intersectsPlanet = rayIntersectSphere(skyPos, viewLocalDir, groundRadiusMM) >= 0.0;

        if (!intersectsPlanet) {
            float sunF = sun(viewLocalDir, scene.SunLocalDir);
            if (sunF > 0.0) skyLight = 10.0 * sunF * scene.SunColor;

            float3 moonLocalPos = moon_distanceKm * scene.MoonLocalDir + localPos;
            float moonHitDist = rayIntersectSphere(moonLocalPos, -viewLocalDir, moon_radiusKm);

            if (moonHitDist > 0.0) {
                skyLight = 10.0 * renderMoon(viewLocalDir, moonLocalPos, moonHitDist, isReflection);
            }
        }
    }

    // if (WORLD_END) {
    //     float3 endSunPos = endSun_distanceKm * -Scene_LocalSunDir + localPos;
    //     float endSunHitDist = rayIntersectSphere(endSunPos, -viewLocalDir, endSun_radiusKm);

    //     if (endSunHitDist > 0.0) {
    //         skyLight = renderEndSun(viewLocalDir, endSunPos, endSunHitDist);
    //     }

    //     float worldTime = ap.time.elapsed;//mod(ap.world.time / 24000.0, 1.0);
    //     float3 endEarthLocalDir = float3(0.0, 0.0, 1.0);
    //     endEarthLocalDir = rotateY(endEarth_orbitSpeed * worldTime * TAU) * endEarthLocalDir;
    //     endEarthLocalDir = rotateX(0.4) * endEarthLocalDir;
    //     endEarthLocalDir = normalize(endEarthLocalDir);

    //     float3 endEarthPos = endEarth_distanceKm * endEarthLocalDir + localPos;
    //     float endEarthHitDist = rayIntersectSphere(endEarthPos, -viewLocalDir, endEarth_radiusKm);

    //     if (endEarthHitDist > 0.0) {
    //         skyLight = renderEndEarth(viewLocalDir, endEarthPos, endEarthHitDist);
    //     }
    // }

    if (WORLD_OVERWORLD) {
        if (intersectsPlanet) skyLight = 0.0;
        else skyLight *= sampleSkyTransmit(skyPos, viewLocalDir);

        skyLight += sampleSkyView(skyPos, viewLocalDir, scene.SunLocalDir);
    }

    return skyLight;
}
