// atlasBounds: [0]=position [1]=size
struct AtlasBounds
{
    float2 CoordMin;
    float2 CoordSize;

    float2 GetAtlasCoord(const in float2 localCoord) {
        return fract(localCoord) * CoordSize + CoordMin;
    }

    float2 GetLocalCoord(const in float2 atlasCoord) {
        return (atlasCoord - CoordMin) / CoordSize;
    }
};

// float2 GetAtlasCoord(const in float2 localCoord, const in float2 atlasTileMin, const in float2 atlasTileSize) {
//     return fract(localCoord) * atlasTileSize + atlasTileMin;
// }

// float2 GetLocalCoord(const in float2 atlasCoord, const in float2 atlasTileMin, const in float2 atlasTileSize) {
//     return (atlasCoord - atlasTileMin) / atlasTileSize;
// }
