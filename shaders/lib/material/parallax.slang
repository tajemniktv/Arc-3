import aperture;
import lib.common;
import lib.sampling.atlas;

extern static const bool MATERIAL_PARALLAX_OPTIMIZE;
extern static const int MATERIAL_PARALLAX_SAMPLES;
extern static const float MATERIAL_PARALLAX_DEPTH;
extern static const float MATERIAL_PARALLAX_MAXDIST;
extern static const int MATERIAL_PARALLAX_TYPE;

static const float ParallaxSharpThreshold = (1.5/255.0);
//const float ParallaxDepthF = MATERIAL_PARALLAX_DEPTH * 0.01;

static const int POM_TYPE_DEFAULT = 0;
static const int POM_TYPE_SMOOTH = 1;
static const int POM_TYPE_SHARP = 2;


float2 GetParallaxCoord(const in float2 texcoord, const in int LOD, const in AtlasBounds atlasBounds, const in float3 tanViewDir, const in float viewDist, out float texDepth, out float3 traceDepth) {
    // WARN: temp workaround
    float2 atlasSize = normalTex.GetDimensions(0);

    float maxTexDepth = 1.0;
    if (MATERIAL_PARALLAX_OPTIMIZE) {
        float2 atlasCoord = atlasBounds.GetAtlasCoord(texcoord);
        float2 atlasSize1 = normalTex.GetDimensions(2);
        maxTexDepth = 1.0 - normalTex.Fetch[int2(atlasCoord * atlasSize1), 2).a;
        maxTexDepth = sqrt(maxTexDepth);
    }

    float ParallaxDepthF = MATERIAL_PARALLAX_DEPTH * 0.01 * maxTexDepth;
    float2 stepCoord = tanViewDir.xy * ParallaxDepthF / (fma(tanViewDir.z, MATERIAL_PARALLAX_SAMPLES, 1.0));
    float stepDepth = maxTexDepth / MATERIAL_PARALLAX_SAMPLES;

    // if (MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH) {
        float2 atlasPixelSize = 1.0 / atlasSize;
        float prevTexDepth;
    // }

    float viewDistF = 1.0 - saturate(viewDist / MATERIAL_PARALLAX_MAXDIST);
    float maxSampleCount = fma(viewDistF, MATERIAL_PARALLAX_SAMPLES, 0.5);

    float2 localSize = atlasSize * atlasBounds.CoordSize;
    if (all(localSize > EPSILON))
        stepCoord.y *= localSize.x / localSize.y;

    int i;
    texDepth = 1.0;
    float depthDist = 1.0;
    for (i = 0; i < MATERIAL_PARALLAX_SAMPLES; i++) {
        if (i > maxSampleCount || depthDist < (1.0/255.0)) break;

        if (MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH) {
            prevTexDepth = texDepth;
        }

        float2 localTraceCoord = fma(float2(i), -stepCoord, texcoord);

        if (MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH) {
            float2 uv[4];
            float2 atlasTileSize = atlasBounds.CoordSize * atlasSize;
            float2 f = GetLinearCoords(localTraceCoord, atlasTileSize, uv);

            uv[0] = atlasBounds.GetAtlasCoord(uv[0]);
            uv[1] = atlasBounds.GetAtlasCoord(uv[1]);
            uv[2] = atlasBounds.GetAtlasCoord(uv[2]);
            uv[3] = atlasBounds.GetAtlasCoord(uv[3]);

            texDepth = TextureLodLinear(normalTex, uv, LOD, f, 3);
        }
        else {
            float2 traceAtlasCoord = atlasBounds.GetAtlasCoord(localTraceCoord);
            texDepth = normalTex.SampleLevel(traceAtlasCoord, int(LOD)).a;
        }

        depthDist = 1.0 - fma(i, stepDepth, texDepth);
    }

    i = max(i - 1, 0);
    float pI = max(i - 1, 0);

    if (MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH) {
        float2 currentTraceOffset = texcoord - i * stepCoord;
        float currentTraceDepth = max(1.0 - i * stepDepth, 0.0);
        float2 prevTraceOffset = texcoord - pI * stepCoord;
        float prevTraceDepth = max(1.0 - pI * stepDepth, 0.0);

        float t = (prevTraceDepth - prevTexDepth) / max(texDepth - prevTexDepth + prevTraceDepth - currentTraceDepth, EPSILON);
        t = saturate(t);

        traceDepth.xy = lerp(prevTraceOffset, currentTraceOffset, t);
        traceDepth.z = lerp(prevTraceDepth, currentTraceDepth, t);
    }
    else {
        traceDepth.xy = texcoord - pI * stepCoord;
        traceDepth.z = max(1.0 - pI * stepDepth, 0.0);
    }

    if (MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH) {
        return atlasBounds.GetAtlasCoord(traceDepth.xy);
    }
    else {
        return atlasBounds.GetAtlasCoord(texcoord - i * stepCoord);
    }
}

// #if MATERIAL_PARALLAX_TYPE == POM_TYPE_SHARP
    float3 GetParallaxSlopeNormal(const in float2 atlasCoord, const in int LOD, AtlasBounds atlasBounds, const in float traceDepth, const in float3 tanViewDir) {
        // WARN: temp workaround
        float2 atlasSize = normalTex.GetDimensions(LOD);

        float2 atlasPixelSize = rcp(atlasSize);
        float atlasAspect = atlasSize.x / atlasSize.y;

        float2 tex_snapped = floor(atlasCoord * atlasSize) * atlasPixelSize;
        float2 tex_offset = atlasCoord - (fma(atlasPixelSize, float2(0.5), tex_snapped));

        float2 stepSign = sign(tex_offset);
        float2 viewSign = sign(-tanViewDir.xy);

        bool dir = abs(tex_offset.x  * atlasAspect) < abs(tex_offset.y);
        float2 tex_x, tex_y;

        if (dir) {
            tex_x = float2(viewSign.x, 0.0);
            tex_y = float2(0.0, stepSign.y);
        }
        else {
            tex_x = float2(stepSign.x, 0.0);
            tex_y = float2(0.0, viewSign.y);
        }

        float2 tX = atlasBounds.GetLocalCoord(fma(tex_x, atlasPixelSize, atlasCoord));
        tX = atlasBounds.GetAtlasCoord(tX);

        float2 tY = atlasBounds.GetLocalCoord(fma(tex_y, atlasPixelSize, atlasCoord));
        tY = atlasBounds.GetAtlasCoord(tY);

        float height_x = normalTex.SampleLevel(tX, int(LOD)).a;
        float height_y = normalTex.SampleLevel(tY, int(LOD)).a;
        float3 signMask = 0.0;

        if (dir) {
            if (!(traceDepth > height_y && -viewSign.y != stepSign.y)) {
                if (traceDepth > height_x)
                    signMask.x = 1.0;
                else if (abs(tanViewDir.y) > abs(tanViewDir.x))
                    signMask.y = 1.0;
                else
                    signMask.x = 1.0;
            }
            else {
                signMask.y = 1.0;
            }
        }
        else {
            if (!(traceDepth > height_x && -viewSign.x != stepSign.x)) {
                if (traceDepth > height_y)
                    signMask.y = 1.0;
                else if (abs(tanViewDir.y) > abs(tanViewDir.x))
                    signMask.y = 1.0;
                else
                    signMask.x = 1.0;
            }
            else {
                signMask.x = 1.0;
            }
        }

        return signMask * float3(viewSign, 0.0);
    }
// #endif
