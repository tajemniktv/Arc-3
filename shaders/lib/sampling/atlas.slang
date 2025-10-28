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

AtlasBounds GetAtlasBounds(const in float2 texcoord, const in float2 midTexCoord) {
    float2 coordNMid = texcoord - midTexCoord;

    AtlasBounds bounds;
    bounds.CoordMin = min(texcoord, midTexCoord - coordNMid);
    bounds.CoordSize = abs(coordNMid) * 2.0;
    return bounds;
}
